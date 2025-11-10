#pragma once

#include <cuda_runtime.h>
#include <cufft.h>

namespace waveviz {

void LaunchCreateWindows(const double* d_series,
                         double* d_windows,
                         int window_size,
                         int batch_windows,
                         int start_index,
                         cudaStream_t stream);

void LaunchComputeMeanDetrend(double* d_windows,
                              double* d_means,
                              int window_size,
                              int batch_windows,
                              bool subtract_mean,
                              cudaStream_t stream);

void LaunchSelectTopHarmonics(const cufftDoubleComplex* d_fft,
                              int window_size,
                              int batch_windows,
                              int min_index,
                              int max_index,
                              int top_harmonics,
                              int* d_top_indices,
                              double* d_top_power,
                              cudaStream_t stream);

void LaunchApplyMask(cufftDoubleComplex* d_fft,
                     int window_size,
                     int batch_windows,
                     int top_harmonics,
                     const int* d_top_indices,
                     cudaStream_t stream);

void LaunchZeroDc(cufftDoubleComplex* d_fft,
                  int window_size,
                  int batch_windows,
                  cudaStream_t stream);

void LaunchExtractLastSample(const double* d_time_domain,
                             const double* d_means,
                             double* d_last_outputs,
                             int window_size,
                             int batch_windows,
                             cudaStream_t stream);

void LaunchDetrendSingle(double* d_window,
                         double* d_mean,
                         int window_size,
                         bool subtract_mean,
                         cudaStream_t stream);

void LaunchExtractLastSingle(const double* d_window,
                             const double* d_mean,
                             double* d_output,
                             int window_size,
                             cudaStream_t stream);

void LaunchShiftWindowInsert(double* d_window,
                             double new_sample,
                             int window_size,
                             cudaStream_t stream);

} // namespace waveviz
