//+------------------------------------------------------------------+
//| GPU Engine Hub                                                   |
//| EA responsável por orquestrar o pipeline GPU assíncrono.         |
//| Integra via GpuEngineClient.dll (serviço único) e HUDs.          |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.000"
#property strict

#import "GpuEngineClient.dll"
int  GpuClient_Open(int device_id,
                    int window_size,
                    int hop_size,
                    int max_batch_size,
                    bool enable_profiling,
                    bool prefer_service,
                    bool tester_mode);
void GpuClient_Close();
int  GpuClient_SubmitJob(const double &frames[],
                         int frame_count,
                         int frame_length,
                         ulong user_tag,
                         uint  flags,
                         const double &preview_mask[],
                         double mask_sigma_period,
                         double mask_threshold,
                         double mask_softness,
                         double mask_min_period,
                         double mask_max_period,
                         int    upscale_factor,
                         const double &cycle_periods[],
                         int    cycle_count,
                         double cycle_width,
                         const double &measurement[],
                         int    measurement_count,
                         int    kalman_preset,
                         double kalman_process_noise,
                         double kalman_measurement_noise,
                         double kalman_init_variance,
                         double kalman_plv_threshold,
                         int    kalman_max_iterations,
                         double kalman_epsilon,
                         double kalman_process_scale,
                         double kalman_measurement_scale,
                         ulong &out_handle);
int  GpuClient_PollStatus(ulong handle_value,
                          int &out_status);
int  GpuClient_FetchResult(ulong handle_value,
                           double &wave_out[],
                           double &preview_out[],
                           double &cycles_out[],
                           double &noise_out[],
                           double &phase_out[],
                           double &phase_unwrapped_out[],
                           double &amplitude_out[],
                           double &period_out[],
                           double &frequency_out[],
                           double &eta_out[],
                           double &countdown_out[],
                           double &recon_out[],
                           double &kalman_out[],
                           double &confidence_out[],
                           double &amp_delta_out[],
                           double &turn_signal_out[],
                           double &direction_out[],
                           double &power_out[],
                           double &velocity_out[],
                           double &phase_all_out[],
                           double &phase_unwrapped_all_out[],
                           double &amplitude_all_out[],
                           double &period_all_out[],
                           double &frequency_all_out[],
                           double &eta_all_out[],
                           double &countdown_all_out[],
                           double &direction_all_out[],
                           double &recon_all_out[],
                           double &kalman_all_out[],
                           double &turn_all_out[],
                           double &confidence_all_out[],
                           double &amp_delta_all_out[],
                           double &power_all_out[],
                           double &velocity_all_out[],
                           double &plv_cycles_out[],
                           double &snr_cycles_out[],
                           GpuEngineResultInfo &info);
int  GpuClient_GetStats(double &avg_ms,
                        double &max_ms);
int  GpuClient_GetLastError(uchar &buffer[],
                            int buffer_len);
int  GpuClient_GetBackendName(uchar &buffer[],
                              int buffer_len);
int  GpuClient_IsServiceBackend();
#import

double g_gpuEmptyPreviewMask[] = { EMPTY_VALUE };
double g_gpuEmptyCyclePeriods[] = { EMPTY_VALUE };
double g_gpuSubmitFrames[];
double g_gpuSubmitMeasurement[];
uchar  g_gpuErrorBuffer[];

bool GpuIsBadValue(const double value)
  {
   if(!MathIsValidNumber(value))
      return true;
   if(value == EMPTY_VALUE || value == DBL_MAX || value == -DBL_MAX)
      return true;
   if(MathAbs(value) >= 1.0e12)
      return true;
   return false;
  }

int GpuSanitizeSeries(const double &source[],
                      double &target[],
                      const int expected_len,
                      int &padded_count)
  {
   const int source_len = ArraySize(source);
   padded_count = 0;
   ArrayResize(target, expected_len);
   double last_valid = 0.0;
   bool has_last = false;
   int replaced = 0;
   for(int i=0; i<expected_len; ++i)
     {
      double value = (i < source_len ? source[i] : EMPTY_VALUE);
      if(i >= source_len)
         ++padded_count;
      if(GpuIsBadValue(value))
        {
         ++replaced;
         double candidate = has_last ? last_valid : 0.0;
         if(GpuIsBadValue(candidate))
            candidate = 0.0;
         value = candidate;
        }
      target[i] = value;
      last_valid = value;
      has_last = true;
     }
   return replaced;
  }

int GpuSanitizeSeriesWithFallback(const double &source[],
                                  const double &fallback[],
                                  double &target[],
                                  const int expected_len,
                                  int &padded_count)
  {
   const int source_len   = ArraySize(source);
   const int fallback_len = ArraySize(fallback);
   padded_count = 0;
   ArrayResize(target, expected_len);
   double last_valid = 0.0;
   bool has_last = false;
   int replaced = 0;
   for(int i=0; i<expected_len; ++i)
     {
      double value = (i < source_len ? source[i] : EMPTY_VALUE);
      if(i >= source_len)
         ++padded_count;
      if(GpuIsBadValue(value))
        {
         ++replaced;
         double candidate = (i < fallback_len ? fallback[i] : EMPTY_VALUE);
         if(GpuIsBadValue(candidate))
            candidate = has_last ? last_valid : 0.0;
         if(GpuIsBadValue(candidate))
            candidate = 0.0;
         value = candidate;
        }
      target[i] = value;
      last_valid = value;
      has_last = true;
     }
   return replaced;
  }

string BoolToText(const bool value)
  {
   return value ? "true" : "false";
  }

string UlongToString(const ulong value)
  {
   return IntegerToString((long)value);
  }

bool g_gpuLoggingEnabled = true;

void GpuSetLogging(const bool enabled)
  {
   g_gpuLoggingEnabled = enabled;
   PrintFormat("[GpuEngine] Logging %s", enabled ? "ON" : "OFF");
  }

bool GpuLogsEnabled()
  {
   return g_gpuLoggingEnabled;
  }

void GpuLogInfo(const string context,
                const string message)
  {
   if(g_gpuLoggingEnabled)
      PrintFormat("[GpuEngine] %s | %s", context, message);
   GPULog::Info(context, message);
  }

#ifndef __GPU_ENGINE_RESULT_INFO__
#define __GPU_ENGINE_RESULT_INFO__
struct GpuEngineResultInfo
  {
  ulong   user_tag;
  int     frame_count;
  int     frame_length;
  int     cycle_count;
  int     dominant_cycle;
  double  dominant_period;
  double  dominant_snr;
  double  dominant_plv;
  double  dominant_confidence;
  double  line_phase_deg;
  double  line_amplitude;
  double  line_period;
  double  line_eta;
  double  line_confidence;
  double  line_value;
  double  elapsed_ms;
  int     status;
  };
#endif

#include <GPU/GPU_Log.mqh>

enum GpuEngineStatus
  {
   GPU_ENGINE_OK          =  0,
   GPU_ENGINE_READY       =  1,
   GPU_ENGINE_IN_PROGRESS =  2,
   GPU_ENGINE_TIMEOUT     =  3,
   GPU_ENGINE_ERROR      = -1
  };

#define GPU_ENGINE_STATUS_NOT_IMPLEMENTED   (-11)

class CGpuEngineClient
  {
private:
   bool   m_ready;
   int    m_window_size;
   int    m_hop_size;
   int    m_batch_size;
   int    m_device_id;
   bool   m_profiling;
   bool   m_tester_mode;
   bool   m_prefer_service;
   string m_backend_label;

   void   RefreshBackend()
            {
               uchar backend_buf[];
               ArrayResize(backend_buf, 64);
               const int backend_len = GpuClient_GetBackendName(backend_buf, ArraySize(backend_buf));
               if(backend_len > 0)
                 {
                  const string label = CharArrayToString(backend_buf, 0, backend_len);
                  m_backend_label = StringToLower(label);
                 }
               else
                 {
                  const bool using_service = (GpuClient_IsServiceBackend() != 0);
                  if(using_service)
                     m_backend_label = "service";
                  else if(m_tester_mode)
                     m_backend_label = "tester";
                  else
                     m_backend_label = "";
                 }
            }

   void   LogError(const string context,
                   const int status) const
            {
               uchar msg_buffer[];
               ArrayResize(msg_buffer, 512);
               const int err_status = GpuClient_GetLastError(msg_buffer, ArraySize(msg_buffer));
               string msg = "";
   if(err_status == GPU_ENGINE_OK)
      msg = CharArrayToString(msg_buffer, 0, -1);
   if(StringLen(msg) > 0)
     {
      GPULog::LogError(context, status, msg);
      PrintFormat("[GpuEngine] %s falhou (status=%d): %s", context, status, msg);
     }
   else
     {
      GPULog::LogError(context, status, "");
      PrintFormat("[GpuEngine] %s falhou (status=%d)", context, status);
     }
   }

public:
            CGpuEngineClient()
            {
               m_ready          = false;
               m_window_size    = 0;
               m_hop_size       = 0;
               m_batch_size     = 0;
               m_device_id      = 0;
               m_profiling      = false;
               m_tester_mode    = false;
               m_prefer_service = false;
               m_backend_label  = "";
            }

   string   ActiveBackendName()
            {
               RefreshBackend();
               return m_backend_label;
            }

   bool     UsingService()
            {
               RefreshBackend();
               return (m_backend_label == "service");
            }

   bool     Initialize(const int device_id,
                       const int window_size,
                       const int hop_size,
                       const int batch_size,
                       const bool enable_profiling,
                       const bool use_service=false)
            {
               m_device_id      = device_id;
               m_window_size    = window_size;
               m_hop_size       = hop_size;
               m_batch_size     = batch_size;
               m_profiling      = enable_profiling;
               m_tester_mode    = (MQLInfoInteger(MQL_TESTER) != 0);
               m_prefer_service = (!m_tester_mode);

               if(!use_service && !m_tester_mode)
                  GpuLogInfo("Initialize", "UseGpuService=false ignorado (serviço é obrigatório nesta build)");
               if(m_tester_mode)
                  GpuLogInfo("Initialize", "Strategy Tester detectado - usando DLL dedicada");

               GpuLogInfo("Initialize",
                          StringFormat("device=%d window=%d hop=%d batch=%d profiling=%s prefer_service=%s tester=%s",
                                       m_device_id,
                                       m_window_size,
                                       m_hop_size,
                                       m_batch_size,
                                       BoolToText(m_profiling),
                                       BoolToText(m_prefer_service),
                                       BoolToText(m_tester_mode)));

               int status = GpuClient_Open(m_device_id,
                                           m_window_size,
                                           m_hop_size,
                                           m_batch_size,
                                           m_profiling,
                                           m_prefer_service,
                                           m_tester_mode);
               if(status != GPU_ENGINE_OK)
                 {
                  LogError("GpuClient_Open", status);
                  m_ready = false;
                  return false;
                 }

               m_ready = true;
               RefreshBackend();
               GpuLogInfo("Initialize", "GpuClient_Open concluído (backend=" + m_backend_label + ")");
               return true;
            }

   void     Shutdown()
            {
               if(!m_ready)
                 {
                  GpuLogInfo("Shutdown", "ignorado - engine não estava inicializada");
                  return;
                 }

               GpuLogInfo("Shutdown", "GpuClient_Close chamado");
               GpuClient_Close();
               m_ready = false;
               m_backend_label = "";
               GpuLogInfo("Shutdown", "GpuClient_Close concluído");
            }

   bool     SubmitJob(const double &frames[],
                      const int frame_count,
                      const ulong user_tag,
                      const uint flags,
                      ulong &out_handle)
            {
              const int measurement_len = frame_count * m_window_size;
              return SubmitJobEx(frames,
                                 frame_count,
                                 user_tag,
                                 flags,
                                 g_gpuEmptyPreviewMask,
                                 g_gpuEmptyCyclePeriods,
                                 0,
                                 0.25,
                                 frames,
                                 measurement_len,
                                 48.0,
                                 0.05,
                                 0.20,
                                 8.0,
                                 512.0,
                                 1,
                                 1,
                                 1.0e-4,
                                 2.5e-3,
                                 0.5,
                                 0.65,
                                 48,
                                 1.0e-4,
                                 1.0,
                                 1.0,
                                 out_handle);
            }

   bool     SubmitJobEx(const double &frames[],
                        const int frame_count,
                        const ulong user_tag,
                        const uint flags,
                        const double &preview_mask[],
                        const double &cycle_periods[],
                        const int cycle_count,
                        const double cycle_width,
                        const double &measurement[],
                        const int measurement_count,
                        const double mask_sigma_period,
                        const double mask_threshold,
                        const double mask_softness,
                        const double mask_min_period,
                        const double mask_max_period,
                        const int upscale_factor,
                        const int kalman_preset,
                        const double kalman_process_noise,
                        const double kalman_measurement_noise,
                        const double kalman_init_variance,
                        const double kalman_plv_threshold,
                        const int    kalman_max_iterations,
                        const double kalman_epsilon,
                        const double kalman_process_scale,
                        const double kalman_measurement_scale,
                        ulong &out_handle)
            {
               if(!m_ready)
                  return false;

               const int expected_total = frame_count * m_window_size;
               if(expected_total <= 0)
                 {
                  GpuLogInfo("SubmitJob", "expected_total inválido; abortando submissão");
                  return false;
                 }

               double safe_mask_min = MathMax(1.0, mask_min_period);
               double safe_mask_max = MathMax(safe_mask_min, mask_max_period);
               int    safe_upscale  = MathMax(upscale_factor, 1);
               int    safe_preset   = (int)MathMax(0, MathMin(3, kalman_preset));
               double safe_process  = MathMax(1.0e-8, kalman_process_noise);
               double safe_measure  = MathMax(1.0e-8, kalman_measurement_noise);
               double safe_init_var = MathMax(1.0e-6, kalman_init_variance);
               double safe_plv      = MathMax(0.0, MathMin(1.0, kalman_plv_threshold));
               int    safe_iters    = MathMax(1, kalman_max_iterations);
               double safe_eps      = MathMax(1.0e-6, kalman_epsilon);
               double safe_proc_scale = MathMax(1.0e-6, kalman_process_scale);
               double safe_meas_scale = MathMax(1.0e-6, kalman_measurement_scale);
               int    safe_measure_count = measurement_count;
               const int measurement_array_size = ArraySize(measurement);
               if(safe_measure_count <= 0 || safe_measure_count > measurement_array_size)
                  safe_measure_count = measurement_array_size;

               GpuLogInfo("SubmitJob",
                          StringFormat("frames=%d window=%d user_tag=%s flags=%u cycles=%d",
                                       frame_count,
                                       m_window_size,
                                       UlongToString(user_tag),
                                       flags,
                                       cycle_count));

               int frame_padded = 0;
               int frame_replaced = GpuSanitizeSeries(frames,
                                                      g_gpuSubmitFrames,
                                                      expected_total,
                                                      frame_padded);

               int measurement_padded = 0;
               int measurement_replaced = 0;
               if(safe_measure_count > 0)
                 {
                  measurement_replaced = GpuSanitizeSeriesWithFallback(measurement,
                                                                       g_gpuSubmitFrames,
                                                                       g_gpuSubmitMeasurement,
                                                                       expected_total,
                                                                       measurement_padded);
                 }
               else
                 {
                  ArrayResize(g_gpuSubmitMeasurement, expected_total);
                  ArrayCopy(g_gpuSubmitMeasurement, g_gpuSubmitFrames, 0, 0, expected_total);
                  measurement_padded = expected_total;
                 }
               safe_measure_count = expected_total;

               if(frame_replaced > 0 || frame_padded > 0)
                  GpuLogInfo("SubmitJob",
                             StringFormat("frames sanitizados (replaced=%d padded=%d)",
                                          frame_replaced,
                                          frame_padded));
               if(measurement_replaced > 0 || measurement_padded > 0)
                  GpuLogInfo("SubmitJob",
                             StringFormat("measurement sanitizada (replaced=%d padded=%d)",
                                          measurement_replaced,
                                          measurement_padded));

               int status = GpuClient_SubmitJob(g_gpuSubmitFrames,
                                                frame_count,
                                                m_window_size,
                                                user_tag,
                                                flags,
                                                preview_mask,
                                                mask_sigma_period,
                                                mask_threshold,
                                                mask_softness,
                                                safe_mask_min,
                                                safe_mask_max,
                                                safe_upscale,
                                                cycle_periods,
                                                cycle_count,
                                                cycle_width,
                                                g_gpuSubmitMeasurement,
                                                safe_measure_count,
                                                safe_preset,
                                                safe_process,
                                                safe_measure,
                                                safe_init_var,
                                                safe_plv,
                                                safe_iters,
                                                safe_eps,
                                                safe_proc_scale,
                                                safe_meas_scale,
                                                out_handle);
               if(status != GPU_ENGINE_OK)
                 {
                  LogError("GpuClient_SubmitJob", status);
                  return false;
                 }

               GpuLogInfo("SubmitJob", "handle=" + UlongToString(out_handle));
               GPULog::LogSubmit(out_handle,
                                 user_tag,
                                 flags,
                                 frame_count,
                                 m_window_size,
                                 cycle_count,
                                 safe_measure_count,
                                 expected_total);
               return true;
            }

   int      PollStatus(const ulong handle,
                       int &out_status)
            {
               out_status = GPU_ENGINE_ERROR;
               if(!m_ready)
                  return GPU_ENGINE_ERROR;
               int status = GpuClient_PollStatus(handle, out_status);
               if(status == GPU_ENGINE_OK)
                  GPULog::LogPoll(handle, out_status);
               else
                  LogError("GpuClient_PollStatus", status);
               return status;
            }

   bool     FetchResult(const ulong handle,
                        double &wave_out[],
                        double &preview_out[],
                        double &cycles_out[],
                        double &noise_out[],
                        double &phase_out[],
                        double &phase_unwrapped_out[],
                        double &amplitude_out[],
                        double &period_out[],
                        double &frequency_out[],
                        double &eta_out[],
                        double &countdown_out[],
                        double &recon_out[],
                        double &kalman_out[],
                        double &confidence_out[],
                        double &amp_delta_out[],
                        double &turn_signal_out[],
                        double &direction_out[],
                        double &power_out[],
                        double &velocity_out[],
                        double &phase_all_out[],
                        double &phase_unwrapped_all_out[],
                        double &amplitude_all_out[],
                        double &period_all_out[],
                        double &frequency_all_out[],
                        double &eta_all_out[],
                        double &countdown_all_out[],
                        double &direction_all_out[],
                        double &recon_all_out[],
                        double &kalman_all_out[],
                        double &turn_all_out[],
                        double &confidence_all_out[],
                        double &amp_delta_all_out[],
                        double &power_all_out[],
                        double &velocity_all_out[],
                        double &plv_cycles_out[],
                        double &snr_cycles_out[],
                        GpuEngineResultInfo &info)
            {
               if(!m_ready)
                  return false;

               GpuLogInfo("FetchResult", "handle=" + UlongToString(handle));
               int status = GpuClient_FetchResult(handle,
                                                  wave_out,
                                                  preview_out,
                                                  cycles_out,
                                                  noise_out,
                                                  phase_out,
                                                  phase_unwrapped_out,
                                                  amplitude_out,
                                                  period_out,
                                                  frequency_out,
                                                  eta_out,
                                                  countdown_out,
                                                  recon_out,
                                                  kalman_out,
                                                  confidence_out,
                                                  amp_delta_out,
                                                  turn_signal_out,
                                                  direction_out,
                                                  power_out,
                                                  velocity_out,
                                                  phase_all_out,
                                                  phase_unwrapped_all_out,
                                                  amplitude_all_out,
                                                  period_all_out,
                                                  frequency_all_out,
                                                  eta_all_out,
                                                  countdown_all_out,
                                                  direction_all_out,
                                                  recon_all_out,
                                                  kalman_all_out,
                                                  turn_all_out,
                                                  confidence_all_out,
                                                  amp_delta_all_out,
                                                  power_all_out,
                                                  velocity_all_out,
                                                  plv_cycles_out,
                                                  snr_cycles_out,
                                                  info);
               if(status != GPU_ENGINE_OK)
                 {
                  LogError("GpuClient_FetchResult", status);
                  return false;
                 }

               RefreshBackend();
               GPULog::LogFetch(handle, info);
               return true;
            }

   bool     GetStats(double &avg_ms,
                     double &max_ms)
            {
               if(!m_ready)
                  return false;
               int status = GpuClient_GetStats(avg_ms, max_ms);
               if(status != GPU_ENGINE_OK)
                 {
                  LogError("GpuClient_GetStats", status);
                  return false;
                 }
               return true;
            }
  };

#include <GPU/GPU_Shared.mqh>

class CHotkeyManager
  {
private:
   int m_keys[];
   int m_actions[];

public:
            CHotkeyManager()
            {
               Reset();
            }

   void     Reset()
            {
               ArrayResize(m_keys, 0);
               ArrayResize(m_actions, 0);
            }

   bool     Register(const int key_code,
                     const int action_id)
            {
               if(key_code <= 0)
                  return false;

               const int count = ArraySize(m_keys);
               for(int i=0; i<count; ++i)
                 {
                  if(m_keys[i] == key_code)
                    {
                     m_actions[i] = action_id;
                     return true;
                    }
                 }

               const int new_size = count + 1;
               ArrayResize(m_keys, new_size);
               ArrayResize(m_actions, new_size);
               m_keys[new_size-1]    = key_code;
               m_actions[new_size-1] = action_id;
               return true;
            }

   int      HandleChartEvent(const int id,
                             const long &lparam) const
            {
               if(id != CHARTEVENT_KEYDOWN)
                  return -1;

               const int key = (int)lparam;
               const int count = ArraySize(m_keys);
               for(int i=0; i<count; ++i)
                 {
                  if(m_keys[i] == key)
                     return m_actions[i];
                 }
               return -1;
            }
  };

enum ZigzagFeedMode
  {
   Feed_PivotHold = 0,
   Feed_PivotBridge = 1,
   Feed_PivotMidpoint = 2
  };

//--- configuração básica do hub
input int    InpGPUDevice     = 0;
input int    InpFFTWindow     = 4096;
input int    InpHop           = 1024;
input int    InpBatchSize     = 128;
input int    InpUpscaleFactor = 1;
input bool   InpProfiling     = false;
input bool   InpUseGpuService = true;
input int    InpTimerPeriodMs = 250;
input bool   InpShowHud       = true;
input bool   InpGpuVerboseLog = false;

input ZigzagFeedMode InpFeedMode        = Feed_PivotHold;
input int            InpZigZagDepth     = 12;
input int            InpZigZagDeviation = 5;
input int            InpZigZagBackstep  = 3;

input double InpGaussSigmaPeriod = 48.0;
input double InpMaskThreshold    = 0.05;
input double InpMaskSoftness     = 0.20;

input double InpMaskMinPeriod   = 18.0;
input double InpMaskMaxPeriod   = 512.0;
input int    InpMaxCandidates   = 12;
input bool   InpUseManualCycles = false;

input double InpCycleWidth    = 0.25;
input double InpCyclePeriod1  = 18.0;
input double InpCyclePeriod2  = 24.0;
input double InpCyclePeriod3  = 30.0;
input double InpCyclePeriod4  = 36.0;
input double InpCyclePeriod5  = 45.0;
input double InpCyclePeriod6  = 60.0;
input double InpCyclePeriod7  = 75.0;
input double InpCyclePeriod8  = 90.0;
input double InpCyclePeriod9  = 120.0;
input double InpCyclePeriod10 = 150.0;
input double InpCyclePeriod11 = 180.0;
input double InpCyclePeriod12 = 240.0;

enum KalmanPresetOption
  {
   KalmanSmooth   = 0,
   KalmanBalanced = 1,
   KalmanReactive = 2,
   KalmanManual   = 3
  };

input KalmanPresetOption InpKalmanPreset         = KalmanBalanced;
input double             InpKalmanProcessNoise   = 1.0e-4;
input double             InpKalmanMeasurementNoise = 2.5e-3;
input double             InpKalmanInitVariance   = 0.5;
input double             InpKalmanPlvThreshold   = 0.65;
input int                InpKalmanMaxIterations  = 48;
input double             InpKalmanConvergenceEps = 1.0e-4;

input bool   InpEnableHotkeys        = true;
input int    InpHotkeyWaveToggle     = 116; // F5
input int    InpHotkeyPhaseToggle    = 117; // F6
input int    InpWaveSubwindow        = 1;
input int    InpPhaseSubwindow       = 2;
input bool   InpWaveShowNoise        = true;
input bool   InpWaveShowCycles       = true;
input int    InpWaveMaxCycles        = 12;
input bool   InpAutoAttachWave       = true;
input bool   InpAutoAttachPhase      = true;

//--- flags para jobs (placeholder)
enum JobFlags
  {
   JOB_FLAG_STFT   = 1,
   JOB_FLAG_CYCLES = 2
  };

struct PendingJob
  {
   ulong    handle;
   ulong    user_tag;
   datetime submitted_at;
   int      frame_count;
   int      frame_length;
   int      cycle_count;
  };

CGpuEngineClient g_engine;
PendingJob        g_jobs[];
double            g_batch_buffer[];
double            g_wave_shared[];
double            g_preview_shared[];
double            g_cycles_shared[];
double            g_noise_shared[];
double            g_phase_shared[];
double            g_phase_unwrapped_shared[];
double            g_amplitude_shared[];
double            g_period_shared[];
double            g_frequency_shared[];
double            g_eta_shared[];
double            g_countdown_shared[];
double            g_recon_shared[];
double            g_kalman_shared[];
double            g_turn_shared[];
double            g_confidence_shared[];
double            g_amp_delta_shared[];
double            g_direction_shared[];
double            g_power_shared[];
double            g_velocity_shared[];
double            g_plv_cycles_shared[];
double            g_snr_cycles_shared[];
datetime          g_lastUpdateTime = 0;

int               g_zigzagHandle   = INVALID_HANDLE;
double            g_zigzagRaw[];
double            g_zigzagSeries[];
double            g_seriesChron[];
int               g_pivotIndex[];
double            g_pivotValue[];
double            g_cyclePeriods[];
double            g_phase_all_shared[];
double            g_phase_unwrapped_all_shared[];
double            g_amplitude_all_shared[];
double            g_period_all_shared[];
double            g_frequency_all_shared[];
double            g_eta_all_shared[];
double            g_countdown_all_shared[];
double            g_direction_all_shared[];
double            g_recon_all_shared[];
double            g_kalman_all_shared[];
double            g_turn_all_shared[];
double            g_confidence_all_shared[];
double            g_amp_delta_all_shared[];
double            g_power_all_shared[];
double            g_velocity_all_shared[];

double            g_lastAvgMs = 0.0;
double            g_lastMaxMs = 0.0;
int               g_lastFrameCount = 0;
int               g_lastFetchBars  = 0;

int               g_handleWaveViz  = INVALID_HANDLE;
int               g_handlePhaseViz = INVALID_HANDLE;
bool              g_waveVisible    = false;
bool              g_phaseVisible   = false;

CHotkeyManager    g_hotkeys;

enum HubActions
  {
   HubAction_None = -1,
   HubAction_ToggleWave = 1,
   HubAction_TogglePhase = 2
  };

const string WAVE_IND_SHORTNAME  = "GPU WaveViz";
const string PHASE_IND_SHORTNAME = "GPU PhaseViz";

void ToggleWaveView();
void TogglePhaseView();

//+------------------------------------------------------------------+
int CollectCyclePeriods(double &dest[])
  {
   static double periods[12];
   periods[0]  = InpCyclePeriod1;
   periods[1]  = InpCyclePeriod2;
   periods[2]  = InpCyclePeriod3;
   periods[3]  = InpCyclePeriod4;
   periods[4]  = InpCyclePeriod5;
   periods[5]  = InpCyclePeriod6;
   periods[6]  = InpCyclePeriod7;
   periods[7]  = InpCyclePeriod8;
   periods[8]  = InpCyclePeriod9;
   periods[9]  = InpCyclePeriod10;
   periods[10] = InpCyclePeriod11;
   periods[11] = InpCyclePeriod12;

   ArrayResize(dest, 0);
   for(int i=0; i<12; ++i)
     {
      if(periods[i] <= 0.0)
         continue;
      int idx = ArraySize(dest);
      ArrayResize(dest, idx+1);
      dest[idx] = periods[i];
     }
   return ArraySize(dest);
  }

//+------------------------------------------------------------------+
bool BuildZigZagSeries(const int samples_needed)
  {
   if(g_zigzagHandle == INVALID_HANDLE || samples_needed <= 0)
      return false;

   int factor = 1;
   int handle = g_zigzagHandle;
   if(handle == INVALID_HANDLE)
      return false;

   const int fetch_samples = samples_needed * factor;

   ArraySetAsSeries(g_zigzagRaw, true);
   ArrayResize(g_zigzagRaw, fetch_samples);
   int copied = CopyBuffer(handle, 0, 0, fetch_samples, g_zigzagRaw);
   if(copied != fetch_samples)
     {
      if(factor > 1)
        {
         Print("[Hub] Upsampling ZigZag insuficiente, revertendo timeframe base.");
         factor = 1;
         handle = g_zigzagHandle;
         ArrayResize(g_zigzagRaw, samples_needed);
         copied = CopyBuffer(handle, 0, 0, samples_needed, g_zigzagRaw);
         if(copied != samples_needed)
           {
            PrintFormat("[Hub] ZigZag CopyBuffer insuficiente (%d/%d)", copied, samples_needed);
            return false;
           }
        }
      else
        {
         PrintFormat("[Hub] ZigZag CopyBuffer insuficiente (%d/%d)", copied, fetch_samples);
         return false;
        }
     }

   const int work_len = (factor == 1 ? samples_needed : fetch_samples);
   double work_series[];
   ArrayResize(work_series, work_len);
   ArrayInitialize(work_series, 0.0);

   ArrayResize(g_pivotIndex, 0);
   ArrayResize(g_pivotValue, 0);

   for(int i=work_len-1; i>=0; --i)
     {
      double price = g_zigzagRaw[i];
      if(price == EMPTY_VALUE || price == 0.0)
         continue;
      int pos = ArraySize(g_pivotIndex);
      ArrayResize(g_pivotIndex, pos+1);
      ArrayResize(g_pivotValue, pos+1);
      g_pivotIndex[pos] = i;
      g_pivotValue[pos] = price;
      work_series[i] = price;
     }

   int pivot_count = ArraySize(g_pivotIndex);
   if(pivot_count < 2)
      return false;

   for(int k=0; k<pivot_count-1; ++k)
     {
      int start_idx = g_pivotIndex[k];
      int end_idx   = g_pivotIndex[k+1];
      double start_val = g_pivotValue[k];
      double end_val   = g_pivotValue[k+1];
      int span = start_idx - end_idx;
      if(span < 0)
         continue;

      for(int offset=0; offset<=span; ++offset)
        {
         int idx = start_idx - offset;
         double value = start_val;
         switch(InpFeedMode)
           {
            case Feed_PivotBridge:
              {
               double t = (span == 0) ? 0.0 : double(offset) / double(span);
               value = start_val + (end_val - start_val) * t;
              }
              break;
            case Feed_PivotMidpoint:
              value = 0.5 * (start_val + end_val);
              break;
            default:
              value = start_val;
              break;
           }
         work_series[idx] = value;
        }
     }

   int first_idx = g_pivotIndex[0];
   for(int idx=work_len-1; idx>first_idx; --idx)
      work_series[idx] = g_pivotValue[0];

   int last_idx = g_pivotIndex[pivot_count-1];
   for(int idx=last_idx-1; idx>=0; --idx)
      work_series[idx] = g_pivotValue[pivot_count-1];

   ArraySetAsSeries(g_zigzagSeries, true);
   ArrayResize(g_zigzagSeries, samples_needed);
   if(factor == 1)
     {
      for(int i=0; i<samples_needed; ++i)
         g_zigzagSeries[i] = work_series[i];
     }
   else
     {
      for(int i=0; i<samples_needed; ++i)
        {
         int src_idx = i * factor;
         if(src_idx >= work_len)
            src_idx = work_len - 1;
         g_zigzagSeries[i] = work_series[src_idx];
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
bool PrepareBatchFrames(const int frame_len,
                        const int frame_count)
  {
   const int window_span = frame_len + (frame_count-1) * InpHop;
   if(window_span <= 0)
      return false;
   if(ArraySize(g_zigzagSeries) < window_span)
      return false;

   ArraySetAsSeries(g_seriesChron, false);
   ArrayResize(g_seriesChron, window_span);
   for(int t=0; t<window_span; ++t)
      g_seriesChron[t] = g_zigzagSeries[window_span-1 - t];

   ArrayResize(g_batch_buffer, frame_len * frame_count);
   int dst = 0;
   for(int frame=0; frame<frame_count; ++frame)
     {
      const int start = frame * InpHop;
      for(int n=0; n<frame_len; ++n)
         g_batch_buffer[dst++] = g_seriesChron[start + n];
     }
   return true;
  }

//+------------------------------------------------------------------+
void UpdateHud()
  {
   if(!InpShowHud)
     {
      Comment("");
      return;
     }

   string line1 = StringFormat("Jobs pendentes: %d | Último update: %s",
                               ArraySize(g_jobs), TimeToString(g_lastUpdateTime, TIME_SECONDS));
   string line2 = StringFormat("GPU avg %.2f ms | max %.2f ms", g_lastAvgMs, g_lastMaxMs);
   GpuEngineResultInfo info = GPUShared::last_info;
   string line3 = StringFormat("Frames %d/%d | hop=%d | amostras=%d",
                               g_lastFrameCount, InpBatchSize, InpHop, g_lastFetchBars);
   string line4 = StringFormat("Dominante idx=%d | período=%.2f | SNR=%.3f | Conf=%.2f",
                               info.dominant_cycle, info.dominant_period, info.dominant_snr, info.dominant_confidence);
   Comment(line1, "\n", line2, "\n", line3, "\n", line4);
  }

//+------------------------------------------------------------------+
void ToggleWaveView()
  {
   const long chart_id = ChartID();
   if(!g_waveVisible)
     {
      const int max_cycles = (int)MathMax(1, MathMin(12, InpWaveMaxCycles));
      g_handleWaveViz = iCustom(_Symbol, _Period, "GPU_WaveViz",
                                InpWaveShowNoise, InpWaveShowCycles, max_cycles);
      if(g_handleWaveViz == INVALID_HANDLE)
        {
         Print("[Hub] Falha ao criar GPU_WaveViz via iCustom");
         return;
        }
      if(!ChartIndicatorAdd(chart_id, InpWaveSubwindow, g_handleWaveViz))
        {
         IndicatorRelease(g_handleWaveViz);
         g_handleWaveViz = INVALID_HANDLE;
         Print("[Hub] ChartIndicatorAdd falhou para GPU_WaveViz");
         return;
        }
      g_waveVisible = true;
      PrintFormat("[Hub] GPU WaveViz ON (sub janela %d)", InpWaveSubwindow);
     }
   else
     {
      ChartIndicatorDelete(chart_id, InpWaveSubwindow, WAVE_IND_SHORTNAME);
      if(g_handleWaveViz != INVALID_HANDLE)
        {
         IndicatorRelease(g_handleWaveViz);
         g_handleWaveViz = INVALID_HANDLE;
        }
      g_waveVisible = false;
      Print("[Hub] GPU WaveViz OFF");
     }
  }

//+------------------------------------------------------------------+
void TogglePhaseView()
  {
   const long chart_id = ChartID();
   if(!g_phaseVisible)
     {
      g_handlePhaseViz = iCustom(_Symbol, _Period, "GPU_PhaseViz");
      if(g_handlePhaseViz == INVALID_HANDLE)
        {
         Print("[Hub] Falha ao criar GPU_PhaseViz via iCustom");
         return;
        }
      if(!ChartIndicatorAdd(chart_id, InpPhaseSubwindow, g_handlePhaseViz))
        {
         IndicatorRelease(g_handlePhaseViz);
         g_handlePhaseViz = INVALID_HANDLE;
         Print("[Hub] ChartIndicatorAdd falhou para GPU_PhaseViz");
         return;
        }
      g_phaseVisible = true;
      PrintFormat("[Hub] GPU PhaseViz ON (sub janela %d)", InpPhaseSubwindow);
     }
   else
     {
      ChartIndicatorDelete(chart_id, InpPhaseSubwindow, PHASE_IND_SHORTNAME);
      if(g_handlePhaseViz != INVALID_HANDLE)
        {
         IndicatorRelease(g_handlePhaseViz);
         g_handlePhaseViz = INVALID_HANDLE;
        }
      g_phaseVisible = false;
      Print("[Hub] GPU PhaseViz OFF");
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   GpuSetLogging(InpGpuVerboseLog);
   GPULog::Init("EngineHub", true, InpGpuVerboseLog);
   GPULog::SetDebug(InpGpuVerboseLog);

   const bool tester_mode = (MQLInfoInteger(MQL_TESTER) != 0);
   bool use_service = InpUseGpuService && !tester_mode;
   if(tester_mode && InpUseGpuService)
      Print("[Hub] Strategy Tester detectado - usando backend DLL");

   if(!g_engine.Initialize(InpGPUDevice, InpFFTWindow, InpHop, InpBatchSize, InpProfiling, use_service))
     {
      Print("[Hub] Falha ao inicializar GpuEngine. EA será desativado.");
      return INIT_FAILED;
     }

   string backend_name = g_engine.ActiveBackendName();
   string backend_desc;
   if(backend_name == "service")
      backend_desc = "serviço (GpuEngineService)";
   else if(backend_name == "tester")
      backend_desc = "DLL dedicada ao Strategy Tester";
   else
      backend_desc = "DLL direta";
   Print("[Hub] Backend ativo: " + backend_desc);
   GPULog::LogOpen(InpGPUDevice,
                   InpFFTWindow,
                   InpHop,
                   InpBatchSize,
                   use_service,
                   tester_mode,
                   backend_name);

   g_zigzagHandle = iCustom(_Symbol, _Period, "ZigZag", InpZigZagDepth, InpZigZagDeviation, InpZigZagBackstep);
   if(g_zigzagHandle == INVALID_HANDLE)
     {
      Print("[Hub] Não foi possível criar instância do ZigZag.");
      g_engine.Shutdown();
      return INIT_FAILED;
     }

   uint timer_period_ms = (uint)MathMax((double)InpTimerPeriodMs, 1.0);
   EventSetMillisecondTimer(timer_period_ms);
   ArrayResize(g_wave_shared,    0);
   ArrayResize(g_preview_shared, 0);
   ArrayResize(g_cycles_shared,  0);
   ArrayResize(g_noise_shared,   0);
   ArrayResize(g_phase_shared,       0);
   ArrayResize(g_amplitude_shared,   0);
   ArrayResize(g_period_shared,      0);
   ArrayResize(g_eta_shared,         0);
   ArrayResize(g_recon_shared,       0);
   ArrayResize(g_confidence_shared,  0);
   ArrayResize(g_amp_delta_shared,   0);

   ArraySetAsSeries(g_zigzagRaw,    true);
   ArraySetAsSeries(g_zigzagSeries, true);
   ArraySetAsSeries(g_seriesChron,  false);

   CollectCyclePeriods(g_cyclePeriods);

   g_hotkeys.Reset();
   if(InpEnableHotkeys)
     {
      if(InpHotkeyWaveToggle > 0)
         g_hotkeys.Register(InpHotkeyWaveToggle, HubAction_ToggleWave);
      if(InpHotkeyPhaseToggle > 0)
         g_hotkeys.Register(InpHotkeyPhaseToggle, HubAction_TogglePhase);
     }

   if(InpAutoAttachWave)
      ToggleWaveView();
   if(InpAutoAttachPhase)
      TogglePhaseView();

   PrintFormat("[Hub] Inicializado | GPU=%d | window=%d | hop=%d | batch=%d",
               InpGPUDevice, InpFFTWindow, InpHop, InpBatchSize);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_engine.Shutdown();
   GPULog::LogClose();
   if(g_zigzagHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_zigzagHandle);
      g_zigzagHandle = INVALID_HANDLE;
     }
   ArrayFree(g_jobs);
   ArrayFree(g_batch_buffer);
   ArrayFree(g_wave_shared);
   ArrayFree(g_preview_shared);
   ArrayFree(g_cycles_shared);
   ArrayFree(g_noise_shared);
   ArrayFree(g_zigzagRaw);
   ArrayFree(g_zigzagSeries);
   ArrayFree(g_seriesChron);
   ArrayFree(g_pivotIndex);
   ArrayFree(g_pivotValue);
  ArrayFree(g_cyclePeriods);
  ArrayFree(g_phase_shared);
  ArrayFree(g_phase_unwrapped_shared);
  ArrayFree(g_amplitude_shared);
  ArrayFree(g_period_shared);
  ArrayFree(g_frequency_shared);
  ArrayFree(g_eta_shared);
  ArrayFree(g_countdown_shared);
  ArrayFree(g_recon_shared);
  ArrayFree(g_kalman_shared);
  ArrayFree(g_turn_shared);
  ArrayFree(g_confidence_shared);
  ArrayFree(g_amp_delta_shared);
  ArrayFree(g_direction_shared);
  ArrayFree(g_power_shared);
  ArrayFree(g_velocity_shared);
  ArrayFree(g_plv_cycles_shared);
  ArrayFree(g_snr_cycles_shared);
  ArrayFree(g_phase_all_shared);
  ArrayFree(g_phase_unwrapped_all_shared);
  ArrayFree(g_amplitude_all_shared);
  ArrayFree(g_period_all_shared);
  ArrayFree(g_frequency_all_shared);
  ArrayFree(g_eta_all_shared);
  ArrayFree(g_countdown_all_shared);
  ArrayFree(g_direction_all_shared);
  ArrayFree(g_recon_all_shared);
  ArrayFree(g_kalman_all_shared);
  ArrayFree(g_turn_all_shared);
  ArrayFree(g_confidence_all_shared);
  ArrayFree(g_amp_delta_all_shared);
  ArrayFree(g_power_all_shared);
  ArrayFree(g_velocity_all_shared);
   const long chart_id = ChartID();
   if(g_waveVisible)
     {
      ChartIndicatorDelete(chart_id, InpWaveSubwindow, WAVE_IND_SHORTNAME);
      if(g_handleWaveViz != INVALID_HANDLE)
        IndicatorRelease(g_handleWaveViz);
     }
   if(g_phaseVisible)
     {
      ChartIndicatorDelete(chart_id, InpPhaseSubwindow, PHASE_IND_SHORTNAME);
      if(g_handlePhaseViz != INVALID_HANDLE)
        IndicatorRelease(g_handlePhaseViz);
     }
   g_handleWaveViz  = INVALID_HANDLE;
   g_handlePhaseViz = INVALID_HANDLE;
   g_waveVisible  = false;
   g_phaseVisible = false;
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   SubmitPendingBatches();
   PollCompletedJobs();
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   SubmitPendingBatches();
   PollCompletedJobs();
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   const int action = g_hotkeys.HandleChartEvent(id, lparam);
   switch(action)
     {
      case HubAction_ToggleWave:
         ToggleWaveView();
         break;
      case HubAction_TogglePhase:
         TogglePhaseView();
         break;
      default:
         break;
     }
  }

//+------------------------------------------------------------------+
void SubmitPendingBatches()
  {
   if(ArraySize(g_jobs) > 0)
      return;

   const int frame_len   = InpFFTWindow;
   const int max_frames  = InpBatchSize;
   const int hop         = MathMax(InpHop, 1);
   if(frame_len <= 0 || max_frames <= 0 || hop <= 0)
      return;

   static int last_warn_bars = -1;
   const int bars_ready = BarsCalculated(g_zigzagHandle);
   if(bars_ready <= 0)
     {
      if(last_warn_bars != bars_ready)
         Print("[Hub] ZigZag ainda sem dados calculados.");
      last_warn_bars = bars_ready;
      return;
     }
   if(bars_ready < frame_len)
     {
      if(last_warn_bars != bars_ready)
         PrintFormat("[Hub] ZigZag ainda sem barras suficientes (%d < %d)", bars_ready, frame_len);
      last_warn_bars = bars_ready;
      return;
     }
   last_warn_bars = -1;

   int frames_possible = 1 + (bars_ready - frame_len) / hop;
   if(frames_possible < 1)
      frames_possible = 1;

   int frame_count = (int)MathMin((double)max_frames, (double)frames_possible);
   const int measurement_count = frame_count * frame_len;

   const int window_span = frame_len + (frame_count-1) * hop;
   int fetch_bars        = window_span + hop;
   if(fetch_bars > bars_ready)
      fetch_bars = bars_ready;

   if(!BuildZigZagSeries(fetch_bars))
      return;
   if(!PrepareBatchFrames(frame_len, frame_count))
      return;

   g_lastFrameCount = frame_count;
   g_lastFetchBars  = fetch_bars;

   int manual_cycle_count = 0;
   if(InpUseManualCycles)
      manual_cycle_count = CollectCyclePeriods(g_cyclePeriods);
   if(manual_cycle_count == 0)
      ArrayResize(g_cyclePeriods, 0);

   ulong handle = 0;
   ulong tag = (ulong)TimeCurrent();
   bool submitted = false;
   int job_cycle_count = 0;
   uint job_flags = JOB_FLAG_STFT;

   if(InpUseManualCycles && manual_cycle_count > 0)
     {
      job_cycle_count = manual_cycle_count;
      job_flags |= JOB_FLAG_CYCLES;
      submitted = g_engine.SubmitJobEx(g_batch_buffer,
                                       frame_count,
                                       tag,
                                       job_flags,
                                       g_gpuEmptyPreviewMask,
                                       g_cyclePeriods,
                                       manual_cycle_count,
                                       InpCycleWidth,
                                       g_batch_buffer,
                                       measurement_count,
                                       InpGaussSigmaPeriod,
                                       InpMaskThreshold,
                                       InpMaskSoftness,
                                       InpMaskMinPeriod,
                                       InpMaskMaxPeriod,
                                       InpUpscaleFactor,
                                       (int)InpKalmanPreset,
                                       InpKalmanProcessNoise,
                                       InpKalmanMeasurementNoise,
                                       InpKalmanInitVariance,
                                       InpKalmanPlvThreshold,
                                       InpKalmanMaxIterations,
                                       InpKalmanConvergenceEps,
                                       1.0,
                                       1.0,
                                       handle);
     }
   else
     {
      job_cycle_count = MathMax(InpMaxCandidates, 0);
      if(job_cycle_count > 0)
         job_flags |= JOB_FLAG_CYCLES;
      submitted = g_engine.SubmitJobEx(g_batch_buffer,
                                       frame_count,
                                       tag,
                                       job_flags,
                                       g_gpuEmptyPreviewMask,
                                       g_gpuEmptyCyclePeriods,
                                       job_cycle_count,
                                       InpCycleWidth,
                                       g_batch_buffer,
                                       measurement_count,
                                       InpGaussSigmaPeriod,
                                       InpMaskThreshold,
                                       InpMaskSoftness,
                                       InpMaskMinPeriod,
                                       InpMaskMaxPeriod,
                                       InpUpscaleFactor,
                                       (int)InpKalmanPreset,
                                       InpKalmanProcessNoise,
                                       InpKalmanMeasurementNoise,
                                       InpKalmanInitVariance,
                                       InpKalmanPlvThreshold,
                                       InpKalmanMaxIterations,
                                       InpKalmanConvergenceEps,
                                       1.0,
                                       1.0,
                                       handle);
     }

   if(!submitted)
      return;

   PendingJob job;
   job.handle       = handle;
   job.user_tag     = tag;
   job.submitted_at = TimeCurrent();
   job.frame_count  = frame_count;
   job.frame_length = frame_len;
   job.cycle_count  = job_cycle_count;
   PushJob(job);
   UpdateHud();
  }

//+------------------------------------------------------------------+
void PollCompletedJobs()
  {
   for(int i=ArraySize(g_jobs)-1; i>=0; --i)
     {
      int status;
      if(g_engine.PollStatus(g_jobs[i].handle, status) != GPU_ENGINE_OK)
         continue;

      if(status == GPU_ENGINE_READY)
        {
         GpuEngineResultInfo info;
         const int total = g_jobs[i].frame_count * g_jobs[i].frame_length;
         const int expected_cycles = MathMax(g_jobs[i].cycle_count, 0);
         const int cycles_total = total * expected_cycles;

         ArrayResize(g_wave_shared,    total);
         ArrayResize(g_preview_shared,total);
         ArrayResize(g_noise_shared,  total);
         ArrayResize(g_cycles_shared, cycles_total);
         ArrayResize(g_phase_shared,            total);
         ArrayResize(g_phase_unwrapped_shared,  total);
         ArrayResize(g_amplitude_shared,        total);
         ArrayResize(g_period_shared,           total);
         ArrayResize(g_frequency_shared,        total);
         ArrayResize(g_eta_shared,              total);
         ArrayResize(g_countdown_shared,        total);
         ArrayResize(g_recon_shared,            total);
         ArrayResize(g_kalman_shared,           total);
         ArrayResize(g_turn_shared,             total);
         ArrayResize(g_confidence_shared,       total);
         ArrayResize(g_amp_delta_shared,        total);
         ArrayResize(g_direction_shared,        total);
         ArrayResize(g_power_shared,            total);
         ArrayResize(g_velocity_shared,         total);

         ArrayResize(g_phase_all_shared,            cycles_total);
         ArrayResize(g_phase_unwrapped_all_shared,  cycles_total);
         ArrayResize(g_amplitude_all_shared,        cycles_total);
         ArrayResize(g_period_all_shared,           cycles_total);
         ArrayResize(g_frequency_all_shared,        cycles_total);
         ArrayResize(g_eta_all_shared,              cycles_total);
         ArrayResize(g_countdown_all_shared,        cycles_total);
         ArrayResize(g_direction_all_shared,        cycles_total);
         ArrayResize(g_recon_all_shared,            cycles_total);
         ArrayResize(g_kalman_all_shared,           cycles_total);
         ArrayResize(g_turn_all_shared,             cycles_total);
         ArrayResize(g_confidence_all_shared,       cycles_total);
         ArrayResize(g_amp_delta_all_shared,        cycles_total);
         ArrayResize(g_power_all_shared,            cycles_total);
         ArrayResize(g_velocity_all_shared,         cycles_total);

         bool fetched = g_engine.FetchResult(g_jobs[i].handle,
                                             g_wave_shared,
                                             g_preview_shared,
                                             g_cycles_shared,
                                             g_noise_shared,
                                             g_phase_shared,
                                             g_phase_unwrapped_shared,
                                             g_amplitude_shared,
                                             g_period_shared,
                                             g_frequency_shared,
                                             g_eta_shared,
                                             g_countdown_shared,
                                             g_recon_shared,
                                             g_kalman_shared,
                                             g_confidence_shared,
                                             g_amp_delta_shared,
                                             g_turn_shared,
                                             g_direction_shared,
                                             g_power_shared,
                                             g_velocity_shared,
                                             g_phase_all_shared,
                                             g_phase_unwrapped_all_shared,
                                             g_amplitude_all_shared,
                                             g_period_all_shared,
                                             g_frequency_all_shared,
                                             g_eta_all_shared,
                                             g_countdown_all_shared,
                                             g_direction_all_shared,
                                             g_recon_all_shared,
                                             g_kalman_all_shared,
                                             g_turn_all_shared,
                                             g_confidence_all_shared,
                                             g_amp_delta_all_shared,
                                             g_power_all_shared,
                                             g_velocity_all_shared,
                                             g_plv_cycles_shared,
                                             g_snr_cycles_shared,
                                             info);

        if(fetched)
          {
            for(int idx=0; idx<total; ++idx)
              {
               g_direction_shared[idx] = (g_countdown_shared[idx] >= 0.0 ? 1.0 : -1.0);
               g_power_shared[idx]     = g_amplitude_shared[idx] * g_amplitude_shared[idx];
               g_velocity_shared[idx]  = g_frequency_shared[idx];
              }
           g_lastUpdateTime = TimeCurrent();
           g_engine.GetStats(g_lastAvgMs, g_lastMaxMs);
            if(info.cycle_count > 0)
              {
               const int cycles_total_actual = total * info.cycle_count;
               if(cycles_total_actual < ArraySize(g_cycles_shared))
                  ArrayResize(g_cycles_shared, cycles_total_actual);
               if(ArraySize(g_cyclePeriods) != info.cycle_count)
                  ArrayResize(g_cyclePeriods, info.cycle_count);
               ArrayResize(g_phase_all_shared,            cycles_total_actual);
               ArrayResize(g_phase_unwrapped_all_shared,  cycles_total_actual);
               ArrayResize(g_amplitude_all_shared,        cycles_total_actual);
               ArrayResize(g_period_all_shared,           cycles_total_actual);
               ArrayResize(g_frequency_all_shared,        cycles_total_actual);
               ArrayResize(g_eta_all_shared,              cycles_total_actual);
               ArrayResize(g_countdown_all_shared,        cycles_total_actual);
               ArrayResize(g_direction_all_shared,        cycles_total_actual);
               ArrayResize(g_recon_all_shared,            cycles_total_actual);
               ArrayResize(g_kalman_all_shared,           cycles_total_actual);
               ArrayResize(g_turn_all_shared,             cycles_total_actual);
               ArrayResize(g_confidence_all_shared,       cycles_total_actual);
               ArrayResize(g_amp_delta_all_shared,        cycles_total_actual);
               ArrayResize(g_power_all_shared,            cycles_total_actual);
               ArrayResize(g_velocity_all_shared,         cycles_total_actual);
               ArrayResize(g_plv_cycles_shared, info.cycle_count);
               ArrayResize(g_snr_cycles_shared, info.cycle_count);
              }
            else
              {
               ArrayResize(g_cycles_shared, 0);
               ArrayResize(g_cyclePeriods, 0);
               ArrayResize(g_phase_all_shared, 0);
               ArrayResize(g_phase_unwrapped_all_shared, 0);
               ArrayResize(g_amplitude_all_shared, 0);
               ArrayResize(g_period_all_shared, 0);
               ArrayResize(g_frequency_all_shared, 0);
               ArrayResize(g_eta_all_shared, 0);
               ArrayResize(g_countdown_all_shared, 0);
               ArrayResize(g_direction_all_shared, 0);
               ArrayResize(g_recon_all_shared, 0);
               ArrayResize(g_kalman_all_shared, 0);
               ArrayResize(g_turn_all_shared, 0);
               ArrayResize(g_confidence_all_shared, 0);
               ArrayResize(g_amp_delta_all_shared, 0);
               ArrayResize(g_power_all_shared, 0);
               ArrayResize(g_velocity_all_shared, 0);
               ArrayResize(g_plv_cycles_shared, 0);
               ArrayResize(g_snr_cycles_shared, 0);
              }
            DispatchSignals(info,
                             g_wave_shared,
                             g_preview_shared,
                             g_noise_shared,
                             g_cycles_shared);
           }

         RemoveJob(i);
        }
     }

   UpdateHud();
  }

//+------------------------------------------------------------------+
void DispatchSignals(const GpuEngineResultInfo &info,
                     const double &wave[],
                     const double &preview[],
                     const double &noise[],
                     const double &cycles[])
  {
  GPUShared::Publish(wave,
                     preview,
                     noise,
                     cycles,
                     g_cyclePeriods,
                     g_phase_shared,
                     g_phase_unwrapped_shared,
                     g_amplitude_shared,
                     g_period_shared,
                     g_frequency_shared,
                      g_eta_shared,
                      g_countdown_shared,
                      g_recon_shared,
                      g_kalman_shared,
                      g_turn_shared,
                      g_confidence_shared,
                      g_amp_delta_shared,
                      g_direction_shared,
                      g_power_shared,
                      g_velocity_shared,
                      g_phase_all_shared,
                      g_phase_unwrapped_all_shared,
                      g_amplitude_all_shared,
                      g_period_all_shared,
                      g_frequency_all_shared,
                      g_eta_all_shared,
                      g_countdown_all_shared,
                      g_direction_all_shared,
                      g_recon_all_shared,
                      g_kalman_all_shared,
                      g_turn_all_shared,
                      g_confidence_all_shared,
                      g_amp_delta_all_shared,
                      g_power_all_shared,
                      g_velocity_all_shared,
                      g_plv_cycles_shared,
                      g_snr_cycles_shared,
                      info);
   // TODO: disparar eventos ou sinalizar variáveis globais, se necessário.
   PrintFormat("[Hub] Job %I64u concluído | frames=%d | elapsed=%.2f ms",
               info.user_tag, info.frame_count, info.elapsed_ms);
   if(info.cycle_count > 0)
      PrintFormat("[Hub] Ciclos retornados: %d", info.cycle_count);
   if(info.dominant_cycle >= 0)
      PrintFormat("[Hub] Dominante idx=%d | período=%.2f | SNR=%.3f | confiança=%.2f",
                  info.dominant_cycle, info.dominant_period, info.dominant_snr, info.dominant_confidence);
  }

//+------------------------------------------------------------------+
void PushJob(const PendingJob &job)
  {
   const int idx = ArraySize(g_jobs);
   ArrayResize(g_jobs, idx + 1);
   g_jobs[idx] = job;
  }

void RemoveJob(const int index)
  {
   const int total = ArraySize(g_jobs);
   if(index < 0 || index >= total)
      return;
   for(int i=index; i<total-1; ++i)
      g_jobs[i] = g_jobs[i+1];
   ArrayResize(g_jobs, total-1);
  }
