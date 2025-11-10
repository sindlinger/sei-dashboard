#include "WaveVizKernels.cuh"

#include <algorithm>
#include <cmath>

namespace waveviz {

namespace {

constexpr int kThreadsPerBlock = 256;
constexpr int kTopLimit = 16;

__global__ void CreateWindowsKernel(const double* series,
                                    double* windows,
                                    int window_size,
                                    int start_index,
                                    int batch_windows) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = window_size * batch_windows;
    if(idx >= total) {
        return;
    }

    int window = idx / window_size;
    int offset = idx % window_size;
    int series_idx = start_index + window + offset;
    windows[static_cast<size_t>(window) * window_size + offset] = series[series_idx];
}

__global__ void ComputeMeanDetrendKernel(double* windows,
                                         double* means,
                                         int window_size,
                                         int batch_windows,
                                         bool subtract_mean) {
    int window = blockIdx.x;
    if(window >= batch_windows) {
        return;
    }

    extern __shared__ double shared[];
    double sum = 0.0;
    for(int idx = threadIdx.x; idx < window_size; idx += blockDim.x) {
        double v = windows[static_cast<size_t>(window) * window_size + idx];
        sum += v;
    }
    shared[threadIdx.x] = sum;
    __syncthreads();

    for(int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if(threadIdx.x < stride) {
            shared[threadIdx.x] += shared[threadIdx.x + stride];
        }
        __syncthreads();
    }

    double mean = shared[0] / static_cast<double>(window_size);
    if(threadIdx.x == 0) {
        means[window] = mean;
    }
    __syncthreads();

    if(subtract_mean) {
        for(int idx = threadIdx.x; idx < window_size; idx += blockDim.x) {
            size_t base = static_cast<size_t>(window) * window_size + idx;
            windows[base] -= mean;
        }
    }
}

__device__ __forceinline__ void InsertTop(double power,
                                          int index,
                                          int top_harmonics,
                                          double* power_buffer,
                                          int* index_buffer) {
    int insert_pos = top_harmonics - 1;
    if(power <= power_buffer[insert_pos]) {
        return;
    }
    while(insert_pos > 0 && power > power_buffer[insert_pos - 1]) {
        power_buffer[insert_pos] = power_buffer[insert_pos - 1];
        index_buffer[insert_pos] = index_buffer[insert_pos - 1];
        --insert_pos;
    }
    power_buffer[insert_pos] = power;
    index_buffer[insert_pos] = index;
}

__global__ void SelectTopKernel(const cufftDoubleComplex* fft,
                                int window_size,
                                int batch_windows,
                                int min_index,
                                int max_index,
                                int top_harmonics,
                                int* top_indices,
                                double* top_power) {
    int window = blockIdx.x;
    if(window >= batch_windows) {
        return;
    }
    const cufftDoubleComplex* fft_window = fft + static_cast<size_t>(window) * window_size;

    extern __shared__ double shared[];
    double* shared_power = shared;
    int* shared_index = reinterpret_cast<int*>(shared_power + blockDim.x * top_harmonics);

    double local_power[kTopLimit];
    int local_index[kTopLimit];
    for(int i = 0; i < kTopLimit; ++i) {
        local_power[i] = -1.0;
        local_index[i] = -1;
    }

    for(int idx = min_index + threadIdx.x; idx <= max_index; idx += blockDim.x) {
        double re = fft_window[idx].x;
        double im = fft_window[idx].y;
        double power = re * re + im * im;
        InsertTop(power, idx, top_harmonics, local_power, local_index);
    }

    for(int i = 0; i < top_harmonics; ++i) {
        shared_power[threadIdx.x * top_harmonics + i] = local_power[i];
        shared_index[threadIdx.x * top_harmonics + i] = local_index[i];
    }
    __syncthreads();

    if(threadIdx.x == 0) {
        double best_power[kTopLimit];
        int best_index[kTopLimit];
        for(int i = 0; i < kTopLimit; ++i) {
            best_power[i] = -1.0;
            best_index[i] = -1;
        }
        int total_candidates = blockDim.x * top_harmonics;
        for(int c = 0; c < total_candidates; ++c) {
            double cand_power = shared_power[c];
            int cand_idx = shared_index[c];
            if(cand_idx < 0) {
                continue;
            }
            InsertTop(cand_power, cand_idx, top_harmonics, best_power, best_index);
        }
        for(int i = 0; i < top_harmonics; ++i) {
            top_indices[window * top_harmonics + i] = best_index[i];
            if(top_power)
                top_power[window * top_harmonics + i] = best_power[i];
        }
    }
}

__global__ void ApplyMaskKernel(cufftDoubleComplex* fft,
                                int window_size,
                                int batch_windows,
                                int top_harmonics,
                                const int* top_indices) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = window_size * batch_windows;
    if(idx >= total) {
        return;
    }
    int window = idx / window_size;
    int bin = idx % window_size;

    bool keep = false;
    for(int i = 0; i < top_harmonics; ++i) {
        int base_idx = top_indices[window * top_harmonics + i];
        if(base_idx <= 0) {
            continue;
        }
        if(bin == base_idx) {
            keep = true;
            break;
        }
        int mirror = window_size - base_idx;
        if(mirror == window_size) {
            mirror = 0;
        }
        if(bin == mirror) {
            keep = true;
            break;
        }
    }
    if(bin == 0) {
        keep = false;
    }
    if(!keep) {
        fft[idx].x = 0.0;
        fft[idx].y = 0.0;
    }
}

__global__ void ExtractLastSampleKernel(const double* windows,
                                        const double* means,
                                        double* outputs,
                                        int window_size,
                                        int batch_windows) {
    int window = blockIdx.x * blockDim.x + threadIdx.x;
    if(window >= batch_windows) {
        return;
    }
    const double* win = windows + static_cast<size_t>(window) * window_size;
    double mean = means[window];
    double value = win[window_size - 1] / static_cast<double>(window_size) + mean;
    outputs[window] = value;
}

__global__ void DetrendSingleKernel(double* window,
                                    double* mean_storage,
                                    int window_size,
                                    bool subtract_mean) {
    extern __shared__ double shared[];
    double sum = 0.0;
    for(int idx = threadIdx.x; idx < window_size; idx += blockDim.x) {
        sum += window[idx];
    }
    shared[threadIdx.x] = sum;
    __syncthreads();

    for(int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if(threadIdx.x < stride) {
            shared[threadIdx.x] += shared[threadIdx.x + stride];
        }
        __syncthreads();
    }

    double mean = shared[0] / static_cast<double>(window_size);
    if(threadIdx.x == 0) {
        mean_storage[0] = mean;
    }
    __syncthreads();

    if(subtract_mean) {
        for(int idx = threadIdx.x; idx < window_size; idx += blockDim.x) {
            window[idx] -= mean;
        }
    }
}

__global__ void ExtractSingleKernel(const double* window,
                                    const double* mean_storage,
                                    double* output,
                                    int window_size) {
    double mean = mean_storage[0];
    double value = window[window_size - 1] / static_cast<double>(window_size) + mean;
    if(threadIdx.x == 0 && blockIdx.x == 0) {
        output[0] = value;
    }
}

__global__ void ShiftInsertKernel(double* window,
                                  double new_sample,
                                  int window_size) {
    int stride = blockDim.x * gridDim.x;
    int start = window_size - 2 - (blockIdx.x * blockDim.x + threadIdx.x);
    for(int idx = start; idx >= 0; idx -= stride) {
        window[idx] = window[idx + 1];
    }
    if(blockIdx.x == 0 && threadIdx.x == 0) {
        window[window_size - 1] = new_sample;
    }
}

} // namespace

void LaunchCreateWindows(const double* d_series,
                         double* d_windows,
                         int window_size,
                         int batch_windows,
                         int start_index,
                         cudaStream_t stream) {
    int total = window_size * batch_windows;
    int blocks = (total + kThreadsPerBlock - 1) / kThreadsPerBlock;
    CreateWindowsKernel<<<blocks, kThreadsPerBlock, 0, stream>>>(
        d_series, d_windows, window_size, start_index, batch_windows);
}

void LaunchComputeMeanDetrend(double* d_windows,
                              double* d_means,
                              int window_size,
                              int batch_windows,
                              bool subtract_mean,
                              cudaStream_t stream) {
    size_t shared = kThreadsPerBlock * sizeof(double);
    ComputeMeanDetrendKernel<<<batch_windows, kThreadsPerBlock, shared, stream>>>(
        d_windows, d_means, window_size, batch_windows, subtract_mean);
}

void LaunchSelectTopHarmonics(const cufftDoubleComplex* d_fft,
                              int window_size,
                              int batch_windows,
                              int min_index,
                              int max_index,
                              int top_harmonics,
                              int* d_top_indices,
                              double* d_top_power,
                              cudaStream_t stream) {
    int threads = kThreadsPerBlock;
    size_t shared = static_cast<size_t>(threads) * top_harmonics * (sizeof(double) + sizeof(int));
    SelectTopKernel<<<batch_windows, threads, shared, stream>>>(
        d_fft, window_size, batch_windows, min_index, max_index, top_harmonics, d_top_indices, d_top_power);
}

void LaunchApplyMask(cufftDoubleComplex* d_fft,
                     int window_size,
                     int batch_windows,
                     int top_harmonics,
                     const int* d_top_indices,
                     cudaStream_t stream) {
    int total = window_size * batch_windows;
    int blocks = (total + kThreadsPerBlock - 1) / kThreadsPerBlock;
    ApplyMaskKernel<<<blocks, kThreadsPerBlock, 0, stream>>>(
        d_fft, window_size, batch_windows, top_harmonics, d_top_indices);
}

__global__ void ZeroDcKernel(cufftDoubleComplex* fft,
                              int window_size,
                              int batch_windows) {
    int window = blockIdx.x * blockDim.x + threadIdx.x;
    if(window >= batch_windows)
        return;

    int base = window * window_size;
    fft[base].x = 0.0;
    fft[base].y = 0.0;

    if(window_size % 2 == 0) {
        int nyquist = base + window_size / 2;
        fft[nyquist].x = 0.0;
        fft[nyquist].y = 0.0;
    }
}

void LaunchZeroDc(cufftDoubleComplex* d_fft,
                  int window_size,
                  int batch_windows,
                  cudaStream_t stream) {
    int threads = std::min(batch_windows, kThreadsPerBlock);
    int blocks = (batch_windows + threads - 1) / threads;
    ZeroDcKernel<<<blocks, threads, 0, stream>>>(d_fft, window_size, batch_windows);
}

void LaunchExtractLastSample(const double* d_time_domain,
                             const double* d_means,
                             double* d_last_outputs,
                             int window_size,
                             int batch_windows,
                             cudaStream_t stream) {
    int threads = std::min(batch_windows, kThreadsPerBlock);
    int blocks = (batch_windows + threads - 1) / threads;
    ExtractLastSampleKernel<<<blocks, threads, 0, stream>>>(
        d_time_domain, d_means, d_last_outputs, window_size, batch_windows);
}

void LaunchDetrendSingle(double* d_window,
                         double* d_mean,
                         int window_size,
                         bool subtract_mean,
                         cudaStream_t stream) {
    size_t shared = kThreadsPerBlock * sizeof(double);
    DetrendSingleKernel<<<1, kThreadsPerBlock, shared, stream>>>(d_window, d_mean, window_size, subtract_mean);
}

void LaunchExtractLastSingle(const double* d_window,
                             const double* d_mean,
                             double* d_output,
                             int window_size,
                             cudaStream_t stream) {
    ExtractSingleKernel<<<1, kThreadsPerBlock, 0, stream>>>(d_window, d_mean, d_output, window_size);
}

void LaunchShiftWindowInsert(double* d_window,
                             double new_sample,
                             int window_size,
                             cudaStream_t stream) {
    int blocks = (window_size + kThreadsPerBlock - 1) / kThreadsPerBlock;
    ShiftInsertKernel<<<blocks, kThreadsPerBlock, 0, stream>>>(d_window, new_sample, window_size);
}

} // namespace waveviz
