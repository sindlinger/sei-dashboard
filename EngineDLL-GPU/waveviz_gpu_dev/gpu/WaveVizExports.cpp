#include "WaveVizContext.h"

#include <cstring>

namespace waveviz {} // namespace waveviz

#ifdef _WIN32
#define WAV_EXPORT extern "C" __declspec(dllexport)
#else
#define WAV_EXPORT extern "C"
#endif

using namespace waveviz;
using namespace gpu;

WAV_EXPORT int WaveVizSessionInit(int device_id) {
    return WaveVizContext::Instance().Initialize(device_id);
}

WAV_EXPORT void WaveVizSessionClose() {
    WaveVizContext::Instance().Shutdown();
}

WAV_EXPORT int WaveVizConfigure(int window_size,
                                int top_harmonics,
                                int min_period,
                                int max_period,
                                int batch_size,
                                int max_history) {
    WaveVizConfig cfg;
    cfg.window_size = window_size;
    cfg.top_harmonics = top_harmonics;
    cfg.min_period = min_period;
    cfg.max_period = max_period;
    cfg.batch_size = (batch_size > 0) ? batch_size : 128;
    cfg.max_history = (max_history > 0) ? max_history : window_size * 4;
    return WaveVizContext::Instance().Configure(cfg);
}

WAV_EXPORT int WaveVizProcessInitial(const double* feed_series,
                                     int feed_length,
                                     double* clean_out,
                                     int* out_valid_count) {
    if(feed_series == nullptr || clean_out == nullptr) {
        return STATUS_INVALID_ARGUMENT;
    }
    return WaveVizContext::Instance().ProcessInitial(feed_series,
                                                     feed_length,
                                                     clean_out,
                                                     out_valid_count);
}

WAV_EXPORT int WaveVizProcessIncremental(const double* feed_samples,
                                         int sample_count,
                                         double* clean_out) {
    if(feed_samples == nullptr || clean_out == nullptr) {
        return STATUS_INVALID_ARGUMENT;
    }
    return WaveVizContext::Instance().ProcessIncremental(feed_samples,
                                                         sample_count,
                                                         clean_out);
}

WAV_EXPORT int WaveVizQueryDominant(double* period,
                                    double* power,
                                    double* amplitude) {
    return WaveVizContext::Instance().QueryDominant(period, power, amplitude);
}
