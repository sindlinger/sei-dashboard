#pragma once

#include <cstddef>
#include <cstdint>
#include <cuda_runtime.h>
#include <cufft.h>

#include "GpuLogger.h"
#include "GpuStatus.h"

namespace waveviz {

struct WaveVizConfig {
    int window_size;
    int top_harmonics;
    int min_period;
    int max_period;
    int batch_size;
    int max_history;

    WaveVizConfig()
        : window_size(0),
          top_harmonics(0),
          min_period(0),
          max_period(0),
          batch_size(0),
          max_history(0) {}
};

class WaveVizContext {
public:
    static WaveVizContext& Instance();

    int Initialize(int device_id);
    void Shutdown();

    int Configure(const WaveVizConfig& cfg);

    int ProcessInitial(const double* feed_series,
                       int feed_length,
                       double* clean_out,
                       int* out_valid_count);

    int ProcessIncremental(const double* feed_samples,
                           int sample_count,
                           double* clean_out);

    int QueryDominant(double* period,
                      double* power,
                      double* amplitude) const;

private:
    WaveVizContext();
    ~WaveVizContext();

    WaveVizContext(const WaveVizContext&) = delete;
    WaveVizContext& operator=(const WaveVizContext&) = delete;

    int EnsureCapacity(int requested_history);
    int PrepareBatchPlan(int batch_size);
    int PrepareSinglePlan();
    void ReleaseResources();

    int ProcessBatch(int start_window,
                     int batch_windows,
                     const double* feed_series,
                     double* clean_out);

    int ProcessSingleWindow(const double* window_host,
                            double* clean_out);

private:
    bool initialized_;
    bool configured_;
    int device_id_;

    // Config
    int window_size_;
    int top_harmonics_;
    int min_index_;
    int max_index_;
    int batch_size_;
    int max_history_;

    // FFT plans
    cufftHandle plan_forward_batch_;
    cufftHandle plan_inverse_batch_;
    cufftHandle plan_forward_single_;
    cufftHandle plan_inverse_single_;
    void* work_forward_batch_;
    void* work_inverse_batch_;
    void* work_forward_single_;
    void* work_inverse_single_;
    size_t work_forward_batch_bytes_;
    size_t work_inverse_batch_bytes_;
    size_t work_forward_single_bytes_;
    size_t work_inverse_single_bytes_;

    // Streams
    cudaStream_t stream_batch_;
    cudaStream_t stream_single_;

    // Device buffers (batch)
    double* d_series_;
    size_t series_capacity_;

    double* d_windows_;
    double* d_means_;
    cufftDoubleComplex* d_fft_;
    double* d_output_last_;
    int* d_top_indices_;
    double* d_top_power_;

    // Device buffers (single window incremental)
    double* d_current_window_feed_;
    double* d_current_window_work_;
    double* d_current_mean_;
    cufftDoubleComplex* d_current_fft_;
    double* d_current_output_;
    int* d_current_top_indices_;
    double* d_current_top_power_;

    // Host helper
    int processed_history_;
    double* h_window_cache_;
    int last_dominant_index_;
    double last_dominant_power_;
    double last_dominant_amplitude_;
};

} // namespace waveviz
