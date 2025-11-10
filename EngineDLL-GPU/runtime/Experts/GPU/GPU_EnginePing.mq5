//+------------------------------------------------------------------+
//| GPU_EnginePing.mq5                                              |
//| Teste mínimo de handshake com GpuEngineService.exe              |
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
int  GpuClient_GetLastError(uchar &buffer[],
                            int buffer_len);
int  GpuClient_GetBackendName(uchar &buffer[],
                              int buffer_len);
int  GpuClient_IsServiceBackend();
#import

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

double g_gpuEmptyPreviewMask[] = { EMPTY_VALUE };
double g_gpuEmptyCyclePeriods[] = { EMPTY_VALUE };

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

input int  InpGPU       = 0;
input int  InpWindow    = 1024;
input int  InpHop       = 256;
input int  InpBatch     = 8;
input bool InpProfiling = false;
input bool InpUseGpuService = true;
input bool InpVerboseLog    = true;

bool g_engine_ready   = false;
bool g_prevGpuLogging = true;

int OnInit()
  {
   const bool tester_mode = (MQLInfoInteger(MQL_TESTER) != 0);
   bool use_service = true;
   if(!tester_mode && !InpUseGpuService)
      Print("[Ping] UseGpuService ignorado (serviço obrigatório nesta build).");

   g_prevGpuLogging = GpuLogsEnabled();
   GpuSetLogging(InpVerboseLog);
   GPULog::Init("EnginePing", true, InpVerboseLog);
   GPULog::SetDebug(InpVerboseLog);
   Print("[Ping] Iniciando teste de conexão...");

   int init_status = GpuClient_Open(InpGPU,
                                   InpWindow,
                                   InpHop,
                                   InpBatch,
                                   InpProfiling,
                                   use_service,
                                   tester_mode);
   if(init_status != GPU_ENGINE_OK)
     {
      uchar err_buffer[];
      ArrayResize(err_buffer, 512);
      int err_code = GpuClient_GetLastError(err_buffer, ArraySize(err_buffer));
      string err = CharArrayToString(err_buffer, 0, -1);
      GPULog::LogError("open", init_status, err);
      PrintFormat("[Ping] GpuEngine_Init falhou (code=%d): %s", err_code, err);
      return INIT_FAILED;
     }

   g_engine_ready = true;

   uchar backend_buffer[];
   ArrayResize(backend_buffer, 64);
   int backend_len = GpuClient_GetBackendName(backend_buffer, ArraySize(backend_buffer));
   string backend_name = (backend_len > 0)
      ? CharArrayToString(backend_buffer, 0, backend_len)
      : (GpuClient_IsServiceBackend() != 0 ? "service" : (tester_mode ? "tester" : "dll"));
   string backend_desc;
   if(backend_name == "service")
      backend_desc = "serviço (GpuEngineService)";
   else if(backend_name == "tester")
      backend_desc = "DLL dedicada ao Strategy Tester";
   else
      backend_desc = "DLL direta";
   Print("[Ping] Backend ativo: " + backend_desc);
   GPULog::LogOpen(InpGPU,
                   InpWindow,
                   InpHop,
                   InpBatch,
                   use_service,
                   tester_mode,
                   backend_name);

   double frames[];
   ArrayResize(frames, MathMax(InpWindow, 1));
   ArrayInitialize(frames, 0.0);

   ulong handle = 0;
   int submit_status = GpuClient_SubmitJob(frames,
                                           1,
                                           InpWindow,
                                           12345,
                                           0,
                                           g_gpuEmptyPreviewMask,
                                           1.0,
                                           0.0,
                                           0.0,
                                           1.0,
                                           512.0,
                                           1,
                                           g_gpuEmptyCyclePeriods,
                                           0,
                                           0.25,
                                           frames,
                                           ArraySize(frames),
                                           0,
                                           1.0e-4,
                                           2.5e-3,
                                           0.5,
                                           0.5,
                                           10,
                                           1.0e-4,
                                           1.0,
                                           1.0,
                                           handle);
   if(submit_status != GPU_ENGINE_OK)
     {
      uchar err_buffer[];
      ArrayResize(err_buffer, 512);
      int err_code = GpuClient_GetLastError(err_buffer, ArraySize(err_buffer));
      string err = CharArrayToString(err_buffer, 0, -1);
      GPULog::LogError("submit", submit_status, err);
      PrintFormat("[Ping] SubmitJob falhou (code=%d): %s", err_code, err);
      return INIT_FAILED;
     }
   GPULog::LogSubmit(handle,
                     12345,
                     0,
                     1,
                     InpWindow,
                     0,
                     ArraySize(frames),
                     ArraySize(frames));

   int status = GPU_ENGINE_IN_PROGRESS;
   for(int i=0; i<20 && status == GPU_ENGINE_IN_PROGRESS; ++i)
     {
      if(GpuClient_PollStatus(handle, status) == GPU_ENGINE_OK)
         GPULog::LogPoll(handle, status);
      Sleep(100);
     }

   if(status != GPU_ENGINE_READY)
     {
      GPULog::LogError("poll", status, "job_not_ready");
      PrintFormat("[Ping] PollStatus terminou com status=%d", status);
      return INIT_FAILED;
     }

   GPULog::Info("ping", "job_ready");
   Print("[Ping] Sucesso! Job concluído e resposta recebida.");

   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   EventKillTimer();
   ExpertRemove();
  }

void OnDeinit(const int reason)
  {
   if(g_engine_ready)
     {
      GpuClient_Close();
      g_engine_ready = false;
      GPULog::LogClose();
     }
   GpuSetLogging(g_prevGpuLogging);
   Print("[Ping] Finalizado.");
  }
