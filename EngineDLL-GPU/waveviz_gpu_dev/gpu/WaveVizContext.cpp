#include "WaveVizContext.h"
#include "WaveVizKernels.cuh"

#include <algorithm>
#include <cstring>
#include <cmath>
#include <memory>
#include <sstream>
#include <cufftXt.h>

namespace waveviz {

namespace {

constexpr int kMaxTopHarmonics = 16;

template <typename Fn>
int WithCuda(Fn&& fn, const char* context) {
    cudaError_t err = fn();
    if(err != cudaSuccess) {
        std::ostringstream oss;
        oss << context << " cuda_error=" << static_cast<int>(err) << " (" << cudaGetErrorString(err) << ")";
        LogMessage(oss.str());
        return STATUS_DEVICE_ERROR;
    }
    return STATUS_OK;
}

template <typename Fn>
int WithCuFft(Fn&& fn, const char* context) {
    cufftResult res = fn();
    if(res != CUFFT_SUCCESS) {
        std::ostringstream oss;
        oss << context << " cufft_error=" << static_cast<int>(res);
        LogMessage(oss.str());
        return STATUS_EXECUTION_ERROR;
    }
    return STATUS_OK;
}

} // namespace

using namespace gpu;

WaveVizContext& WaveVizContext::Instance() {
    static WaveVizContext ctx;
    return ctx;
}

WaveVizContext::WaveVizContext()
    : initialized_(false),
      configured_(false),
      device_id_(0),
      window_size_(0),
      top_harmonics_(0),
      min_index_(0),
      max_index_(0),
      batch_size_(0),
      max_history_(0),
      plan_forward_batch_(0),
      plan_inverse_batch_(0),
      plan_forward_single_(0),
      plan_inverse_single_(0),
      work_forward_batch_(nullptr),
      work_inverse_batch_(nullptr),
      work_forward_single_(nullptr),
      work_inverse_single_(nullptr),
      work_forward_batch_bytes_(0),
      work_inverse_batch_bytes_(0),
      work_forward_single_bytes_(0),
      work_inverse_single_bytes_(0),
      stream_batch_(nullptr),
      stream_single_(nullptr),
      d_series_(nullptr),
      series_capacity_(0),
      d_windows_(nullptr),
      d_means_(nullptr),
      d_fft_(nullptr),
      d_output_last_(nullptr),
      d_top_indices_(nullptr),
      d_top_power_(nullptr),
      d_current_window_feed_(nullptr),
      d_current_window_work_(nullptr),
      d_current_mean_(nullptr),
      d_current_fft_(nullptr),
      d_current_output_(nullptr),
      d_current_top_indices_(nullptr),
      d_current_top_power_(nullptr),
      processed_history_(0),
      h_window_cache_(nullptr),
      last_dominant_index_(0),
      last_dominant_power_(0.0),
      last_dominant_amplitude_(0.0) {}

WaveVizContext::~WaveVizContext() {
    Shutdown();
}

int WaveVizContext::Initialize(int device_id) {
    if(initialized_) {
        return STATUS_ALREADY_INITIALIZED;
    }

    int device_count = 0;
    cudaError_t err = cudaGetDeviceCount(&device_count);
    if(err != cudaSuccess || device_count <= 0) {
        LogMessage("WaveViz: cudaGetDeviceCount failed or no CUDA devices");
        return STATUS_DEVICE_ERROR;
    }

    if(device_id < 0 || device_id >= device_count) {
        std::ostringstream oss;
        oss << "WaveViz: invalid device id " << device_id << ", total=" << device_count;
        LogMessage(oss.str());
        return STATUS_INVALID_ARGUMENT;
    }

    if(cudaSetDevice(device_id) != cudaSuccess) {
        LogMessage("WaveViz: cudaSetDevice failed");
        return STATUS_DEVICE_ERROR;
    }

    device_id_ = device_id;
    if(cudaStreamCreateWithFlags(&stream_batch_, cudaStreamNonBlocking) != cudaSuccess) {
        LogMessage("WaveViz: cudaStreamCreate batch failed");
        return STATUS_DEVICE_ERROR;
    }
    if(cudaStreamCreateWithFlags(&stream_single_, cudaStreamNonBlocking) != cudaSuccess) {
        LogMessage("WaveViz: cudaStreamCreate single failed");
        cudaStreamDestroy(stream_batch_);
        stream_batch_ = nullptr;
        return STATUS_DEVICE_ERROR;
    }

    initialized_ = true;
    LogMessage("WaveViz: context initialized");
    return STATUS_OK;
}

void WaveVizContext::Shutdown() {
    ReleaseResources();
    if(stream_batch_) {
        cudaStreamDestroy(stream_batch_);
        stream_batch_ = nullptr;
    }
    if(stream_single_) {
        cudaStreamDestroy(stream_single_);
        stream_single_ = nullptr;
    }
    initialized_ = false;
    configured_ = false;
    processed_history_ = 0;
    if(h_window_cache_) {
        delete[] h_window_cache_;
        h_window_cache_ = nullptr;
    }
}

void WaveVizContext::ReleaseResources() {
    if(plan_forward_batch_ != 0) {
        cufftDestroy(plan_forward_batch_);
        plan_forward_batch_ = 0;
    }
    if(plan_inverse_batch_ != 0) {
        cufftDestroy(plan_inverse_batch_);
        plan_inverse_batch_ = 0;
    }
    if(plan_forward_single_ != 0) {
        cufftDestroy(plan_forward_single_);
        plan_forward_single_ = 0;
    }
    if(plan_inverse_single_ != 0) {
        cufftDestroy(plan_inverse_single_);
        plan_inverse_single_ = 0;
    }

    if(work_forward_batch_) {
        cudaFree(work_forward_batch_);
        work_forward_batch_ = nullptr;
        work_forward_batch_bytes_ = 0;
    }
    if(work_inverse_batch_) {
        cudaFree(work_inverse_batch_);
        work_inverse_batch_ = nullptr;
        work_inverse_batch_bytes_ = 0;
    }
    if(work_forward_single_) {
        cudaFree(work_forward_single_);
        work_forward_single_ = nullptr;
        work_forward_single_bytes_ = 0;
    }
    if(work_inverse_single_) {
        cudaFree(work_inverse_single_);
        work_inverse_single_ = nullptr;
        work_inverse_single_bytes_ = 0;
    }

    if(d_series_) {
        cudaFree(d_series_);
        d_series_ = nullptr;
        series_capacity_ = 0;
    }
    if(d_windows_) {
        cudaFree(d_windows_);
        d_windows_ = nullptr;
    }
    if(d_means_) {
        cudaFree(d_means_);
        d_means_ = nullptr;
    }
    if(d_fft_) {
        cudaFree(d_fft_);
        d_fft_ = nullptr;
    }
    if(d_output_last_) {
        cudaFree(d_output_last_);
        d_output_last_ = nullptr;
    }
    if(d_top_indices_) {
        cudaFree(d_top_indices_);
        d_top_indices_ = nullptr;
    }
    if(d_top_power_) {
        cudaFree(d_top_power_);
        d_top_power_ = nullptr;
    }
    if(d_current_window_feed_) {
        cudaFree(d_current_window_feed_);
        d_current_window_feed_ = nullptr;
    }
    if(d_current_window_work_) {
        cudaFree(d_current_window_work_);
        d_current_window_work_ = nullptr;
    }
    if(d_current_mean_) {
        cudaFree(d_current_mean_);
        d_current_mean_ = nullptr;
    }
    if(d_current_fft_) {
        cudaFree(d_current_fft_);
        d_current_fft_ = nullptr;
    }
    if(d_current_output_) {
        cudaFree(d_current_output_);
        d_current_output_ = nullptr;
    }
    if(d_current_top_indices_) {
        cudaFree(d_current_top_indices_);
        d_current_top_indices_ = nullptr;
    }
    if(d_current_top_power_) {
        cudaFree(d_current_top_power_);
        d_current_top_power_ = nullptr;
    }
}

int WaveVizContext::Configure(const WaveVizConfig& cfg) {
    if(!initialized_) {
        return STATUS_NOT_INITIALIZED;
    }

    if(cfg.window_size <= 0 || cfg.top_harmonics <= 0 || cfg.min_period <= 0 || cfg.max_period <= 0) {
        return STATUS_INVALID_ARGUMENT;
    }
    if(cfg.top_harmonics > kMaxTopHarmonics) {
        return STATUS_INVALID_ARGUMENT;
    }
    if(cfg.min_period > cfg.max_period) {
        return STATUS_INVALID_ARGUMENT;
    }

    ReleaseResources();

    window_size_ = cfg.window_size;
    top_harmonics_ = cfg.top_harmonics;
    batch_size_ = std::max(1, cfg.batch_size);
    max_history_ = std::max(cfg.max_history, cfg.window_size);

    min_index_ = std::max(1, window_size_ / cfg.max_period);
    max_index_ = std::min(window_size_ / 2, std::max(1, window_size_ / cfg.min_period));
    if(max_index_ < min_index_) {
        max_index_ = min_index_;
    }

    int status = PrepareBatchPlan(batch_size_);
    if(status != STATUS_OK) {
        return status;
    }
    status = PrepareSinglePlan();
    if(status != STATUS_OK) {
        return status;
    }

    size_t window_bytes = static_cast<size_t>(window_size_) * sizeof(double);
    size_t window_complex_bytes = static_cast<size_t>(window_size_) * sizeof(cufftDoubleComplex);

    // Batch buffers
    size_t batch_window_bytes = static_cast<size_t>(window_size_) * batch_size_ * sizeof(double);
    if(WithCuda([&]() { return cudaMalloc(&d_windows_, batch_window_bytes); }, "WaveViz cudaMalloc windows") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_means_, batch_size_ * sizeof(double)); }, "WaveViz cudaMalloc means") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_fft_, batch_size_ * window_complex_bytes); }, "WaveViz cudaMalloc fft") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_output_last_, batch_size_ * sizeof(double)); }, "WaveViz cudaMalloc output") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_top_indices_, batch_size_ * top_harmonics_ * sizeof(int)); }, "WaveViz cudaMalloc top_indices") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_top_power_, batch_size_ * top_harmonics_ * sizeof(double)); }, "WaveViz cudaMalloc top_power") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    // Single window buffers
    if(WithCuda([&]() { return cudaMalloc(&d_current_window_feed_, window_bytes); }, "WaveViz cudaMalloc current_window_feed") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_current_window_work_, window_bytes); }, "WaveViz cudaMalloc current_window_work") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_current_mean_, sizeof(double)); }, "WaveViz cudaMalloc current_mean") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_current_fft_, window_complex_bytes); }, "WaveViz cudaMalloc current_fft") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_current_output_, sizeof(double)); }, "WaveViz cudaMalloc current_output") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_current_top_indices_, top_harmonics_ * sizeof(int)); }, "WaveViz cudaMalloc current_top_indices") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(WithCuda([&]() { return cudaMalloc(&d_current_top_power_, top_harmonics_ * sizeof(double)); }, "WaveViz cudaMalloc current_top_power") != STATUS_OK)
        return STATUS_MEMORY_ERROR;

    if(h_window_cache_) {
        delete[] h_window_cache_;
    }
    h_window_cache_ = new double[window_size_];
    processed_history_ = 0;
    last_dominant_index_ = 0;
    last_dominant_power_ = 0.0;
    last_dominant_amplitude_ = 0.0;

    configured_ = true;

    std::ostringstream oss;
    oss << "WaveViz: configured window=" << window_size_
        << " harmonics=" << top_harmonics_
        << " min_index=" << min_index_
        << " max_index=" << max_index_
        << " batch_size=" << batch_size_;
    LogMessage(oss.str());
    return STATUS_OK;
}

int WaveVizContext::EnsureCapacity(int requested_history) {
    if(requested_history <= static_cast<int>(series_capacity_)) {
        return STATUS_OK;
    }
    size_t desired = static_cast<size_t>(requested_history);
    double* new_series = nullptr;
    if(WithCuda([&]() { return cudaMalloc(&new_series, desired * sizeof(double)); }, "WaveViz cudaMalloc series") != STATUS_OK) {
        return STATUS_MEMORY_ERROR;
    }
    if(d_series_) {
        cudaMemcpyAsync(new_series, d_series_, series_capacity_ * sizeof(double), cudaMemcpyDeviceToDevice, stream_batch_);
        cudaFree(d_series_);
    }
    d_series_ = new_series;
    series_capacity_ = desired;
    return STATUS_OK;
}

int WaveVizContext::PrepareBatchPlan(int batch_size) {
    size_t work_size = 0;
    if(cufftCreate(&plan_forward_batch_) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftCreate forward batch failed");
        return STATUS_PLAN_ERROR;
    }
    cufftSetAutoAllocation(plan_forward_batch_, 0);
    if(cufftMakePlanMany(plan_forward_batch_,
                         1,
                         &window_size_,
                         nullptr,
                         1,
                         window_size_,
                         nullptr,
                         1,
                         window_size_,
                         CUFFT_D2Z,
                         batch_size,
                         &work_size) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftMakePlanMany forward failed");
        cufftDestroy(plan_forward_batch_);
        plan_forward_batch_ = 0;
        return STATUS_PLAN_ERROR;
    }
    work_forward_batch_bytes_ = work_size;
    if(work_size > 0) {
        if(cudaMalloc(&work_forward_batch_, work_size) != cudaSuccess) {
            cufftDestroy(plan_forward_batch_);
            plan_forward_batch_ = 0;
            work_forward_batch_ = nullptr;
            work_forward_batch_bytes_ = 0;
            LogMessage("WaveViz: cudaMalloc work_forward failed");
            return STATUS_MEMORY_ERROR;
        }
        cufftSetWorkArea(plan_forward_batch_, work_forward_batch_);
        std::ostringstream oss;
        oss << "WaveViz: forward batch workspace=" << work_size << " bytes";
        LogMessage(oss.str());
    }
    cufftSetStream(plan_forward_batch_, stream_batch_);

    work_size = 0;
    if(cufftCreate(&plan_inverse_batch_) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftCreate inverse batch failed");
        return STATUS_PLAN_ERROR;
    }
    cufftSetAutoAllocation(plan_inverse_batch_, 0);
    if(cufftMakePlanMany(plan_inverse_batch_,
                         1,
                         &window_size_,
                         nullptr,
                         1,
                         window_size_,
                         nullptr,
                         1,
                         window_size_,
                         CUFFT_Z2D,
                         batch_size,
                         &work_size) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftMakePlanMany inverse failed");
        cufftDestroy(plan_inverse_batch_);
        plan_inverse_batch_ = 0;
        if(work_forward_batch_) {
            cudaFree(work_forward_batch_);
            work_forward_batch_ = nullptr;
            work_forward_batch_bytes_ = 0;
        }
        return STATUS_PLAN_ERROR;
    }
    work_inverse_batch_bytes_ = work_size;
    if(work_size > 0) {
        if(cudaMalloc(&work_inverse_batch_, work_size) != cudaSuccess) {
            cufftDestroy(plan_inverse_batch_);
            plan_inverse_batch_ = 0;
            if(work_forward_batch_) {
                cudaFree(work_forward_batch_);
                work_forward_batch_ = nullptr;
                work_forward_batch_bytes_ = 0;
            }
            LogMessage("WaveViz: cudaMalloc work_inverse failed");
            return STATUS_MEMORY_ERROR;
        }
        cufftSetWorkArea(plan_inverse_batch_, work_inverse_batch_);
        std::ostringstream oss;
        oss << "WaveViz: inverse batch workspace=" << work_size << " bytes";
        LogMessage(oss.str());
    }
    cufftSetStream(plan_inverse_batch_, stream_batch_);
    return STATUS_OK;
}

int WaveVizContext::PrepareSinglePlan() {
    size_t work_size = 0;
    if(cufftCreate(&plan_forward_single_) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftCreate forward single failed");
        return STATUS_PLAN_ERROR;
    }
    cufftSetAutoAllocation(plan_forward_single_, 0);
    if(cufftMakePlan1d(plan_forward_single_,
                       window_size_,
                       CUFFT_D2Z,
                       1,
                       &work_size) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftMakePlan1d forward single failed");
        cufftDestroy(plan_forward_single_);
        plan_forward_single_ = 0;
        return STATUS_PLAN_ERROR;
    }
    work_forward_single_bytes_ = work_size;
    if(work_size > 0) {
        if(cudaMalloc(&work_forward_single_, work_size) != cudaSuccess) {
            cufftDestroy(plan_forward_single_);
            plan_forward_single_ = 0;
            work_forward_single_ = nullptr;
            work_forward_single_bytes_ = 0;
            LogMessage("WaveViz: cudaMalloc work_forward_single failed");
            return STATUS_MEMORY_ERROR;
        }
        cufftSetWorkArea(plan_forward_single_, work_forward_single_);
    }
    cufftSetStream(plan_forward_single_, stream_single_);

    work_size = 0;
    if(cufftCreate(&plan_inverse_single_) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftCreate inverse single failed");
        return STATUS_PLAN_ERROR;
    }
    cufftSetAutoAllocation(plan_inverse_single_, 0);
    if(cufftMakePlan1d(plan_inverse_single_,
                       window_size_,
                       CUFFT_Z2D,
                       1,
                       &work_size) != CUFFT_SUCCESS) {
        LogMessage("WaveViz: cufftMakePlan1d inverse single failed");
        cufftDestroy(plan_inverse_single_);
        plan_inverse_single_ = 0;
        if(work_forward_single_) {
            cudaFree(work_forward_single_);
            work_forward_single_ = nullptr;
            work_forward_single_bytes_ = 0;
        }
        return STATUS_PLAN_ERROR;
    }
    work_inverse_single_bytes_ = work_size;
    if(work_size > 0) {
        if(cudaMalloc(&work_inverse_single_, work_size) != cudaSuccess) {
            cufftDestroy(plan_inverse_single_);
            plan_inverse_single_ = 0;
            if(work_forward_single_) {
                cudaFree(work_forward_single_);
                work_forward_single_ = nullptr;
                work_forward_single_bytes_ = 0;
            }
            LogMessage("WaveViz: cudaMalloc work_inverse_single failed");
            return STATUS_MEMORY_ERROR;
        }
        cufftSetWorkArea(plan_inverse_single_, work_inverse_single_);
    }
    cufftSetStream(plan_inverse_single_, stream_single_);
    return STATUS_OK;
}

int WaveVizContext::ProcessBatch(int start_window,
                                 int batch_windows,
                                 const double* feed_series,
                                 double* clean_out) {
    int start_index = start_window;
    // Build window matrix on device
    LaunchCreateWindows(d_series_, d_windows_, window_size_, batch_windows, start_index, stream_batch_);

    LaunchComputeMeanDetrend(d_windows_, d_means_, window_size_, batch_windows, false, stream_batch_);

    if(WithCuFft([&]() {
            return cufftExecD2Z(plan_forward_batch_,
                                reinterpret_cast<cufftDoubleReal*>(d_windows_),
                                d_fft_);
        }, "WaveViz cufftExecD2Z batch") != STATUS_OK) {
        return STATUS_EXECUTION_ERROR;
    }

    LaunchZeroDc(d_fft_, window_size_, batch_windows, stream_batch_);

    LaunchSelectTopHarmonics(d_fft_,
                             window_size_,
                             batch_windows,
                             min_index_,
                             max_index_,
                             top_harmonics_,
                             d_top_indices_,
                             d_top_power_,
                             stream_batch_);

    LaunchApplyMask(d_fft_,
                    window_size_,
                    batch_windows,
                    top_harmonics_,
                    d_top_indices_,
                    stream_batch_);

    if(WithCuFft([&]() {
            return cufftExecZ2D(plan_inverse_batch_,
                                d_fft_,
                                reinterpret_cast<cufftDoubleReal*>(d_windows_));
        }, "WaveViz cufftExecZ2D batch") != STATUS_OK) {
        return STATUS_EXECUTION_ERROR;
    }

    LaunchExtractLastSample(d_windows_,
                            d_means_,
                            d_output_last_,
                            window_size_,
                            batch_windows,
                            stream_batch_);

    size_t bytes = static_cast<size_t>(batch_windows) * sizeof(double);
    if(WithCuda([&]() { return cudaMemcpyAsync(clean_out,
                                              d_output_last_,
                                              bytes,
                                              cudaMemcpyDeviceToHost,
                                              stream_batch_); },
                "WaveViz cudaMemcpy output") != STATUS_OK) {
        return STATUS_DEVICE_ERROR;
    }

    if(cudaStreamSynchronize(stream_batch_) != cudaSuccess) {
        LogMessage("WaveViz: cudaStreamSynchronize batch failed");
        return STATUS_DEVICE_ERROR;
    }

    int dominant_idx = -1;
    double dominant_power = 0.0;
    cudaMemcpyAsync(&dominant_idx,
                    d_top_indices_ + (batch_windows - 1) * top_harmonics_,
                    sizeof(int),
                    cudaMemcpyDeviceToHost,
                    stream_batch_);
    cudaMemcpyAsync(&dominant_power,
                    d_top_power_ + (batch_windows - 1) * top_harmonics_,
                    sizeof(double),
                    cudaMemcpyDeviceToHost,
                    stream_batch_);
    if(cudaStreamSynchronize(stream_batch_) == cudaSuccess) {
        if(dominant_idx > 0) {
            last_dominant_index_ = dominant_idx;
            last_dominant_power_ = dominant_power;
            last_dominant_amplitude_ = 2.0 * sqrt(dominant_power) / static_cast<double>(window_size_);
        } else {
            last_dominant_index_ = 0;
            last_dominant_power_ = 0.0;
            last_dominant_amplitude_ = 0.0;
        }
    }

    return STATUS_OK;
}

int WaveVizContext::ProcessInitial(const double* feed_series,
                                   int feed_length,
                                   double* clean_out,
                                   int* out_valid_count) {
    if(!configured_) {
        return STATUS_NOT_CONFIGURED;
    }
    if(feed_length < window_size_) {
        return STATUS_INVALID_ARGUMENT;
    }

    int status = EnsureCapacity(feed_length);
    if(status != STATUS_OK) {
        return status;
    }

    size_t bytes = static_cast<size_t>(feed_length) * sizeof(double);
    if(WithCuda([&]() { return cudaMemcpyAsync(d_series_,
                                              feed_series,
                                              bytes,
                                              cudaMemcpyHostToDevice,
                                              stream_batch_); },
                "WaveViz cudaMemcpy series") != STATUS_OK) {
        return STATUS_DEVICE_ERROR;
    }
    if(cudaStreamSynchronize(stream_batch_) != cudaSuccess) {
        LogMessage("WaveViz: cudaStreamSynchronize after copy failed");
        return STATUS_DEVICE_ERROR;
    }

    int window_count = feed_length - window_size_ + 1;
    int processed = 0;
    while(processed < window_count) {
        int batch_windows = std::min(batch_size_, window_count - processed);
        int res = ProcessBatch(processed, batch_windows, feed_series, clean_out + processed);
        if(res != STATUS_OK) {
            return res;
        }
        processed += batch_windows;
    }

    if(out_valid_count) {
        *out_valid_count = window_count;
    }

    // Prepare incremental state using last window from host data
    std::memcpy(h_window_cache_, feed_series + (feed_length - window_size_), window_size_ * sizeof(double));
    if(WithCuda([&]() {
           return cudaMemcpyAsync(d_current_window_feed_,
                                   h_window_cache_,
                                   window_size_ * sizeof(double),
                                   cudaMemcpyHostToDevice,
                                   stream_single_);
       }, "WaveViz cudaMemcpy current_window") != STATUS_OK) {
        return STATUS_DEVICE_ERROR;
    }
    cudaStreamSynchronize(stream_single_);

    processed_history_ = feed_length;
    return STATUS_OK;
}

int WaveVizContext::ProcessSingleWindow(const double* window_host,
                                        double* clean_out) {
    if(window_host != nullptr) {
        if(WithCuda([&]() {
               return cudaMemcpyAsync(d_current_window_feed_,
                                       window_host,
                                       window_size_ * sizeof(double),
                                       cudaMemcpyHostToDevice,
                                       stream_single_);
           }, "WaveViz cudaMemcpy single window") != STATUS_OK) {
            return STATUS_DEVICE_ERROR;
        }
    }
    if(WithCuda([&]() {
           return cudaMemcpyAsync(d_current_window_work_,
                                   d_current_window_feed_,
                                   window_size_ * sizeof(double),
                                   cudaMemcpyDeviceToDevice,
                                   stream_single_);
       }, "WaveViz cudaMemcpy device window") != STATUS_OK) {
        return STATUS_DEVICE_ERROR;
    }

    LaunchDetrendSingle(d_current_window_work_, d_current_mean_, window_size_, false, stream_single_);

    if(WithCuFft([&]() {
            return cufftExecD2Z(plan_forward_single_,
                                reinterpret_cast<cufftDoubleReal*>(d_current_window_work_),
                                d_current_fft_);
        }, "WaveViz cufftExecD2Z single") != STATUS_OK) {
        return STATUS_EXECUTION_ERROR;
    }

    LaunchZeroDc(d_current_fft_, window_size_, 1, stream_single_);

    LaunchSelectTopHarmonics(d_current_fft_,
                             window_size_,
                             1,
                             min_index_,
                             max_index_,
                             top_harmonics_,
                             d_current_top_indices_,
                             d_current_top_power_,
                             stream_single_);

    LaunchApplyMask(d_current_fft_,
                    window_size_,
                    1,
                    top_harmonics_,
                    d_current_top_indices_,
                    stream_single_);

    if(WithCuFft([&]() {
            return cufftExecZ2D(plan_inverse_single_,
                                d_current_fft_,
                                reinterpret_cast<cufftDoubleReal*>(d_current_window_work_));
        }, "WaveViz cufftExecZ2D single") != STATUS_OK) {
        return STATUS_EXECUTION_ERROR;
    }

    LaunchExtractLastSingle(d_current_window_work_,
                            d_current_mean_,
                            d_current_output_,
                            window_size_,
                            stream_single_);

    if(WithCuda([&]() {
           return cudaMemcpyAsync(clean_out,
                                   d_current_output_,
                                   sizeof(double),
                                   cudaMemcpyDeviceToHost,
                                   stream_single_);
       }, "WaveViz cudaMemcpy single output") != STATUS_OK) {
        return STATUS_DEVICE_ERROR;
    }
    if(cudaStreamSynchronize(stream_single_) != cudaSuccess) {
        LogMessage("WaveViz: cudaStreamSynchronize single failed");
        return STATUS_DEVICE_ERROR;
    }

    int dominant_idx = -1;
    double dominant_power = 0.0;
    if(cudaMemcpyAsync(&dominant_idx,
                       d_current_top_indices_,
                       sizeof(int),
                       cudaMemcpyDeviceToHost,
                       stream_single_) == cudaSuccess &&
       cudaMemcpyAsync(&dominant_power,
                       d_current_top_power_,
                       sizeof(double),
                       cudaMemcpyDeviceToHost,
                       stream_single_) == cudaSuccess &&
       cudaStreamSynchronize(stream_single_) == cudaSuccess) {
        if(dominant_idx > 0) {
            last_dominant_index_ = dominant_idx;
            last_dominant_power_ = dominant_power;
            last_dominant_amplitude_ = 2.0 * sqrt(dominant_power) / static_cast<double>(window_size_);
        } else {
            last_dominant_index_ = 0;
            last_dominant_power_ = 0.0;
            last_dominant_amplitude_ = 0.0;
        }
    }
    return STATUS_OK;
}

int WaveVizContext::ProcessIncremental(const double* feed_samples,
                                       int sample_count,
                                       double* clean_out) {
    if(!configured_) {
        return STATUS_NOT_CONFIGURED;
    }
    if(sample_count <= 0) {
        return STATUS_INVALID_ARGUMENT;
    }
    int status = STATUS_OK;
    for(int i = 0; i < sample_count; ++i) {
        double sample = feed_samples[i];
        LaunchShiftWindowInsert(d_current_window_feed_, sample, window_size_, stream_single_);

        status = ProcessSingleWindow(nullptr, clean_out + i);
        if(status != STATUS_OK) {
            return status;
        }

        // Update host cache for potential future CPU side usage
        std::memmove(h_window_cache_, h_window_cache_ + 1, (window_size_ - 1) * sizeof(double));
        h_window_cache_[window_size_ - 1] = sample;
        processed_history_ += 1;
    }
    return STATUS_OK;
}

int WaveVizContext::QueryDominant(double* period,
                                  double* power,
                                  double* amplitude) const {
    if(!configured_) {
        return STATUS_NOT_CONFIGURED;
    }
    if(period) {
        *period = (last_dominant_index_ > 0)
                   ? static_cast<double>(window_size_) / static_cast<double>(last_dominant_index_)
                   : 0.0;
    }
    if(power) {
        *power = last_dominant_power_;
    }
    if(amplitude) {
        *amplitude = last_dominant_amplitude_;
    }
    return STATUS_OK;
}

} // namespace waveviz
