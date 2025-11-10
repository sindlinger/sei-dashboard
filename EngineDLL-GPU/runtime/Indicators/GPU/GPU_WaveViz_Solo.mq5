//+------------------------------------------------------------------+
//| GPU_WaveViz_Solo.mq5                                            |
//| Visualização autônoma da wave reconstruída pela GPU.            |
//| Inclui HUD, linha "perfeita" colada no preço e marcadores       |
//| de countdown/turn em tempo real.                                |
//+------------------------------------------------------------------+
#property copyright   "2025"
#property version     "2.000"
#property strict

#property indicator_separate_window
#property indicator_buffers 29
#property indicator_plots   29

#property indicator_label1  "Wave"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_width1  2

#property indicator_label2  "Noise"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_width2  1

#property indicator_label3  "Cycle1"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue

#property indicator_label4  "Cycle2"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDeepSkyBlue

#property indicator_label5  "Cycle3"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrAqua

#property indicator_label6  "Cycle4"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrSpringGreen

#property indicator_label7  "Cycle5"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrGreen

#property indicator_label8  "Cycle6"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrYellowGreen

#property indicator_label9  "Cycle7"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrOrange

#property indicator_label10 "Cycle8"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrTomato

#property indicator_label11 "Cycle9"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrCrimson

#property indicator_label12 "Cycle10"
#property indicator_type12  DRAW_LINE
#property indicator_color12 clrViolet

#property indicator_label13 "Cycle11"
#property indicator_type13  DRAW_LINE
#property indicator_color13 clrMagenta

#property indicator_label14 "Cycle12"
#property indicator_type14  DRAW_LINE
#property indicator_color14 clrSlateBlue

#property indicator_label15 "Cycle13"
#property indicator_type15  DRAW_LINE
#property indicator_color15 clrOrangeRed

#property indicator_label16 "Cycle14"
#property indicator_type16  DRAW_LINE
#property indicator_color16 clrLime

#property indicator_label17 "Cycle15"
#property indicator_type17  DRAW_LINE
#property indicator_color17 clrSkyBlue

#property indicator_label18 "Cycle16"
#property indicator_type18  DRAW_LINE
#property indicator_color18 clrOrange

#property indicator_label19 "Cycle17"
#property indicator_type19  DRAW_LINE
#property indicator_color19 clrGold

#property indicator_label20 "Cycle18"
#property indicator_type20  DRAW_LINE
#property indicator_color20 clrDarkTurquoise

#property indicator_label21 "Cycle19"
#property indicator_type21  DRAW_LINE
#property indicator_color21 clrPaleGreen

#property indicator_label22 "Cycle20"
#property indicator_type22  DRAW_LINE
#property indicator_color22 clrMediumSlateBlue

#property indicator_label23 "Cycle21"
#property indicator_type23  DRAW_LINE
#property indicator_color23 clrDeepPink

#property indicator_label24 "Cycle22"
#property indicator_type24  DRAW_LINE
#property indicator_color24 clrCornflowerBlue

#property indicator_label25 "Cycle23"
#property indicator_type25  DRAW_LINE
#property indicator_color25 clrKhaki

#property indicator_label26 "Cycle24"
#property indicator_type26  DRAW_LINE
#property indicator_color26 clrMediumPurple

#property indicator_label27 "Dominant"
#property indicator_type27  DRAW_LINE
#property indicator_color27 clrSpringGreen
#property indicator_width27 2

#property indicator_label28 "Perfect"
#property indicator_type28  DRAW_LINE
#property indicator_color28 clrDodgerBlue
#property indicator_width28 2

#property indicator_label29 "Countdown"
#property indicator_type29  DRAW_LINE
#property indicator_color29 clrTomato

#include <Object.mqh>

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

enum GpuEngineStatus
  {
   GPU_ENGINE_OK          =  0,
   GPU_ENGINE_READY       =  1,
   GPU_ENGINE_IN_PROGRESS =  2,
   GPU_ENGINE_TIMEOUT     =  3,
   GPU_ENGINE_ERROR      = -1
  };

#define GPU_ENGINE_STATUS_NOT_IMPLEMENTED   (-11)

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

#include <GPU/GPU_Log.mqh>

double g_gpuEmptyPreviewMask[] = { EMPTY_VALUE };
double g_gpuEmptyCyclePeriods[] = { EMPTY_VALUE };
bool   g_engine_ready  = false;
int    g_engine_window = 0;
bool   g_prevLogging   = true;

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

bool IsBadSample(const double value)
  {
   if(!MathIsValidNumber(value))
      return true;
   if(value == EMPTY_VALUE || value == DBL_MAX || value == -DBL_MAX)
      return true;
   if(MathAbs(value) >= 1.0e12)
      return true;
   return false;
  }

int SanitizeBuffer(double &buffer[])
  {
   const int total = ArraySize(buffer);
   double last_valid = 0.0;
   bool   has_last = false;
   int    replaced = 0;
   for(int i=0; i<total; ++i)
     {
      double value = buffer[i];
      if(IsBadSample(value))
        {
         double candidate = has_last ? last_valid : 0.0;
         if(IsBadSample(candidate))
            candidate = 0.0;
         buffer[i] = candidate;
         ++replaced;
         value = candidate;
        }
      last_valid = value;
      has_last = true;
     }
   return replaced;
  }

void SimpleMovingAverage(const double &src[], const int period, double &dest[])
  {
   const int len = ArraySize(src);
   ArrayResize(dest, len);
   if(period <= 1)
     {
      ArrayCopy(dest, src, 0, 0, len);
      return;
     }
   double sum = 0.0;
   for(int i=0; i<len; ++i)
     {
      sum += src[i];
      if(i >= period)
         sum -= src[i-period];
      if(i >= period-1)
         dest[i] = sum / period;
      else
         dest[i] = src[i];
     }
  }

void TriangularMovingAverage(const double &src[], const int period, double &dest[])
  {
   const int len = ArraySize(src);
   if(period <= 1)
     {
      ArrayResize(dest, len);
      ArrayCopy(dest, src, 0, 0, len);
      return;
     }
   int first_period  = (period + 1) / 2;
   int second_period = (period / 2) + 1;
   SimpleMovingAverage(src, first_period, g_maTemp1);
   SimpleMovingAverage(g_maTemp1, second_period, g_maTemp2);
   ArrayResize(dest, len);
   ArrayCopy(dest, g_maTemp2, 0, 0, len);
  }

void ReverseArray(double &data[])
  {
   const int size = ArraySize(data);
   for(int i=0, j=size-1; i<j; ++i, --j)
     {
      const double tmp = data[i];
      data[i] = data[j];
      data[j] = tmp;
     }
  }

bool EnsureZigZagHandle()
  {
   if(!UsesZigZagFeed())
      return true;
   if(g_zigzagHandle != INVALID_HANDLE)
      return true;
   g_zigzagHandle = iCustom(_Symbol, _Period, "ZigZag",
                            InpZigZagDepth,
                            InpZigZagDeviation,
                            InpZigZagBackstep);
   if(g_zigzagHandle == INVALID_HANDLE)
     {
      PrintFormat("[WaveViz Solo] Falha ao inicializar ZigZag (depth=%d deviation=%d backstep=%d)",
                  InpZigZagDepth, InpZigZagDeviation, InpZigZagBackstep);
      return false;
     }
   return true;
  }

bool BuildZigZagSeries(const int samples_needed)
  {
   if(!UsesZigZagFeed())
      return false;
   if(g_zigzagHandle == INVALID_HANDLE)
      return false;
   if(samples_needed <= 0)
      return false;

   ArraySetAsSeries(g_zigzagRaw, true);
   ArrayResize(g_zigzagRaw, samples_needed);
   const int copied = CopyBuffer(g_zigzagHandle, 0, 0, samples_needed, g_zigzagRaw);
   if(copied != samples_needed)
     {
      if(InpVerboseLog)
         PrintFormat("[WaveViz Solo] ZigZag insuficiente (%d/%d)", copied, samples_needed);
      return false;
     }

   ArrayResize(g_pivotIndex, 0);
   ArrayResize(g_pivotValue, 0);

   for(int i=samples_needed-1; i>=0; --i)
     {
      const double price = g_zigzagRaw[i];
      if(price == EMPTY_VALUE || price == 0.0)
         continue;
      const int pos = ArraySize(g_pivotIndex);
      ArrayResize(g_pivotIndex, pos+1);
      ArrayResize(g_pivotValue, pos+1);
      g_pivotIndex[pos] = i;
      g_pivotValue[pos] = price;
     }

   const int pivot_count = ArraySize(g_pivotIndex);
   if(pivot_count < 2)
      return false;

   double work_series[];
   ArrayResize(work_series, samples_needed);
   ArrayInitialize(work_series, 0.0);

   for(int k=0; k<pivot_count-1; ++k)
     {
      const int start_idx = g_pivotIndex[k];
      const int end_idx   = g_pivotIndex[k+1];
      const double start_val = g_pivotValue[k];
      const double end_val   = g_pivotValue[k+1];
      const int span = start_idx - end_idx;
      if(span < 0)
         continue;
      for(int offset=0; offset<=span; ++offset)
        {
         const int idx = start_idx - offset;
         double value = start_val;
         switch(InpFeedMode)
           {
            case Feed_ZigZagBridge:
              {
               const double t = (span == 0) ? 0.0 : double(offset) / double(span);
               value = start_val + (end_val - start_val) * t;
              }
              break;
            case Feed_ZigZagMidpoint:
              value = 0.5 * (start_val + end_val);
              break;
            default:
              value = start_val;
              break;
           }
         work_series[idx] = value;
        }
     }

   const int first_idx = g_pivotIndex[0];
   for(int idx=samples_needed-1; idx>first_idx; --idx)
      work_series[idx] = g_pivotValue[0];

   const int last_idx = g_pivotIndex[pivot_count-1];
   for(int idx=last_idx-1; idx>=0; --idx)
      work_series[idx] = g_pivotValue[pivot_count-1];

   ArraySetAsSeries(g_zigzagSeries, true);
   ArrayResize(g_zigzagSeries, samples_needed);
   for(int i=0; i<samples_needed; ++i)
      g_zigzagSeries[i] = work_series[i];
   return true;
  }

bool BuildPriceSeries()
  {
   ArrayResize(g_priceSeries, InpFFTWindow);
   ArraySetAsSeries(g_priceSeries, true);

   const int copied = CopyClose(_Symbol, _Period, 0, InpFFTWindow, g_priceSeries);
   if(copied != InpFFTWindow)
      return(false);

   ArraySetAsSeries(g_priceSeries, false);
   ReverseArray(g_priceSeries);
   const int sanitized = SanitizeBuffer(g_priceSeries);
   if(sanitized > 0 && InpVerboseLog)
      PrintFormat("[WaveViz Solo] Price sanitizados=%d", sanitized);
   return(true);
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
   if(!g_gpuLoggingEnabled)
      return;
   PrintFormat("[GpuEngine] %s | %s", context, message);
  }

enum SoloFeedMode
  {
   Feed_Close = 0,
   Feed_ZigZagHold,
   Feed_ZigZagBridge,
   Feed_ZigZagMidpoint
  };

enum KalmanPresetOption
  {
   KalmanSmooth   = 0,
   KalmanBalanced = 1,
   KalmanReactive = 2,
   KalmanManual   = 3
  };

enum WaveButton
  {
   WaveButton_Wave = 0,
   WaveButton_Noise,
   WaveButton_Perfect,
   WaveButton_Dominant,
   WaveButton_Cycles,
   WaveButton_Countdown,
   WaveButton_Markers,
   WaveButton_Hud,
   WaveButton_Total
  };

input bool        InpVerboseLog      = true;
input int         InpGPUDevice       = 0;
input int         InpFFTWindow       = 14384;
input int         InpHop             = 1024;
input bool        InpUseManualCycles = false;
input int         InpCycleCount      = 6;
input double      InpCycleMinPeriod  = 18.0;
input double      InpCycleMaxPeriod  = 1440.0;
input double      InpCycleWidth      = 0.25;
input int         InpMaxCandidates   = 6;
input double      InpGaussSigmaPeriod       = 48.0;
input double      InpMaskThreshold   = 0.05;
input double      InpMaskSoftness    = 0.20;
input double      InpMaskMinPeriod   = 18.0;
input double      InpMaskMaxPeriod   = 512.0;
input KalmanPresetOption InpKalmanPreset         = KalmanBalanced;
input double             InpKalmanProcessNoise   = 1.0e-4;
input double             InpKalmanMeasurementNoise = 2.5e-3;
input double             InpKalmanInitVariance   = 0.5;
input double             InpKalmanPlvThreshold   = 0.35;
input int                InpKalmanMaxIterations  = 48;
input double             InpKalmanConvergenceEps = 1.0e-4;
input SoloFeedMode       InpFeedMode             = Feed_ZigZagBridge;
input int                InpZigZagDepth          = 12;
input int                InpZigZagDeviation      = 5;
input int                InpZigZagBackstep       = 3;
input int                InpTriangularPeriod     = 15;
input bool               InpUseGpuService        = true;

input int   InpButtonCorner    = CORNER_LEFT_UPPER;
input int   InpButtonX         = 10;
input int   InpButtonY         = 20;
input int   InpButtonWidth     = 90;
input int   InpButtonHeight    = 18;
input int   InpButtonSpacing   = 5;
input color InpButtonColor     = clrDimGray;
input color InpButtonTextColor = clrWhite;
input color InpButtonActive    = clrDodgerBlue;

bool EnsureCapacity(double &buffer[], const int required, const string name)
  {
   if(required <= 0)
      return true;
   const int current = ArraySize(buffer);
   if(current >= required)
      return true;
   int result = ArrayResize(buffer, required);
   if(result == -1)
     {
      if(InpVerboseLog)
         PrintFormat("[WaveViz Solo] Falha ao redimensionar %s para %d", name, required);
      return false;
     }
   return true;
  }

const uint JOB_FLAG_STFT   = 1;
const uint JOB_FLAG_CYCLES = 2;
const int  WAVE_BUTTONS_PER_ROW   = 6;
const int  WAVE_TOP_CYCLES        = 6;
const int  WAVE_MAX_OVERLAY_POINTS= 512;
const int  WAVE_MAX_MARKERS       = 20;

const string WAVE_BUTTON_PREFIX = "gpu_wave_solo_btn_";
const string WAVE_PRICE_OBJECT  = "gpu_wave_price_overlay";
const string WAVE_MARKER_PREFIX = "gpu_wave_marker_";
const string WAVE_BUTTON_NAMES[WaveButton_Total] = {
   "Wave",
   "Noise",
   "Perfect",
   "Dominant",
   "Cycles",
   "Countdown",
   "Markers",
   "HUD"
};

//--- indicator buffers
double g_bufWave[];
double g_bufNoise[];
double g_bufCycle1[];
double g_bufCycle2[];
double g_bufCycle3[];
double g_bufCycle4[];
double g_bufCycle5[];
double g_bufCycle6[];
double g_bufCycle7[];
double g_bufCycle8[];
double g_bufCycle9[];
double g_bufCycle10[];
double g_bufCycle11[];
double g_bufCycle12[];
double g_bufCycle13[];
double g_bufCycle14[];
double g_bufCycle15[];
double g_bufCycle16[];
double g_bufCycle17[];
double g_bufCycle18[];
double g_bufCycle19[];
double g_bufCycle20[];
double g_bufCycle21[];
double g_bufCycle22[];
double g_bufCycle23[];
double g_bufCycle24[];
double g_bufDominant[];
double g_bufPerfect[];
double g_bufCountdown[];

//--- engine buffers
double g_frames[];
double g_cyclePeriods[];
double g_waveOut[];
double g_previewOut[];
double g_cyclesOut[];
double g_noiseOut[];
double g_phaseOut[];
double g_phaseUnwrappedOut[];
double g_amplitudeOut[];
double g_periodOut[];
double g_frequencyOut[];
double g_etaOut[];
double g_countdownOut[];
double g_reconOut[];
double g_kalmanOut[];
double g_confidenceOut[];
double g_ampDeltaOut[];
double g_turnOut[];
double g_directionOut[];
double g_powerOut[];
double g_velocityOut[];

double g_phaseAllOut[];
double g_phaseUnwrappedAllOut[];
double g_amplitudeAllOut[];
double g_periodAllOut[];
double g_frequencyAllOut[];
double g_etaAllOut[];
double g_countdownAllOut[];
double g_directionAllOut[];
double g_reconAllOut[];
double g_kalmanAllOut[];
double g_turnAllOut[];
double g_confidenceAllOut[];
double g_ampDeltaAllOut[];
double g_powerAllOut[];
double g_velocityAllOut[];

double g_plvCyclesOut[];
double g_snrCyclesOut[];

int    g_zigzagHandle   = INVALID_HANDLE;
double g_zigzagRaw[];
double g_zigzagSeries[];
int    g_pivotIndex[];
double g_pivotValue[];
double g_priceSeries[];
double g_measureSeries[];
double g_maTemp1[];
double g_maTemp2[];

bool   g_buttonState[WaveButton_Total];
string g_statusText = "";
string g_backendSummary = "";
ulong  g_lastOverlayTag = 0;
ulong  g_lastMarkerTag  = 0;

struct PendingJob
  {
   bool  active;
   ulong handle;
   ulong tag;
   int   submitted_bars;
  };

PendingJob g_job = { false, 0, 0, -1 };
GpuEngineResultInfo g_lastInfo;

//--- forward declarations
string ButtonName(const int index);
int    FindButtonIndex(const string &name);
void   CreateButtons();
void   DestroyButtons();
void   UpdateButtons();
void   ApplyVisibility();
void   ClearCycleBuffers();
void   SetCycleValue(const int index,
                     const int bar_index,
                     const double value);
int    SanitizeBuffer(double &buffer[]);
void   SimpleMovingAverage(const double &src[], const int period, double &dest[]);
void   TriangularMovingAverage(const double &src[], const int period, double &dest[]);
void   ReverseArray(double &data[]);
bool   UsesZigZagFeed();
bool   EnsureZigZagHandle();
bool   BuildZigZagSeries(const int samples_needed);
bool   BuildPriceSeries();
void   BuildCyclePeriods();
bool   PrepareFrames();
bool   SubmitJob(const int rates_total);
void   EnsureFetchBuffers(const int frame_total,
                          const int cycle_total,
                          const int cycle_count);
void   CopyResultsToBuffers(const GpuEngineResultInfo &info);
bool   FetchCurrentResult();
void   RefreshPriceOverlay(const datetime &time[], const double &close[], const int rates_total);
void   RefreshDentMarkers(const datetime &time[], const double &close[], const int rates_total);
void   ClearDentMarkers();
void   UpdateHudText();

//--- helpers -------------------------------------------------------
string ButtonName(const int index)
  {
   return WAVE_BUTTON_PREFIX + WAVE_BUTTON_NAMES[index];
  }

int FindButtonIndex(const string &name)
  {
   for(int i=0; i<WaveButton_Total; ++i)
      if(name == ButtonName(i))
         return i;
   return -1;
  }

void ClearCycleBuffers()
  {
   ArrayInitialize(g_bufCycle1,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle2,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle3,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle4,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle5,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle6,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle7,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle8,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle9,  EMPTY_VALUE);
   ArrayInitialize(g_bufCycle10, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle11, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle12, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle13, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle14, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle15, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle16, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle17, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle18, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle19, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle20, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle21, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle22, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle23, EMPTY_VALUE);
   ArrayInitialize(g_bufCycle24, EMPTY_VALUE);
  }

void SetCycleValue(const int index,
                   const int bar_index,
                   const double value)
  {
   switch(index)
     {
      case 0:  g_bufCycle1[bar_index]  = value; break;
      case 1:  g_bufCycle2[bar_index]  = value; break;
      case 2:  g_bufCycle3[bar_index]  = value; break;
      case 3:  g_bufCycle4[bar_index]  = value; break;
      case 4:  g_bufCycle5[bar_index]  = value; break;
      case 5:  g_bufCycle6[bar_index]  = value; break;
      case 6:  g_bufCycle7[bar_index]  = value; break;
      case 7:  g_bufCycle8[bar_index]  = value; break;
      case 8:  g_bufCycle9[bar_index]  = value; break;
      case 9:  g_bufCycle10[bar_index] = value; break;
      case 10: g_bufCycle11[bar_index] = value; break;
      case 11: g_bufCycle12[bar_index] = value; break;
      case 12: g_bufCycle13[bar_index] = value; break;
      case 13: g_bufCycle14[bar_index] = value; break;
      case 14: g_bufCycle15[bar_index] = value; break;
      case 15: g_bufCycle16[bar_index] = value; break;
      case 16: g_bufCycle17[bar_index] = value; break;
      case 17: g_bufCycle18[bar_index] = value; break;
      case 18: g_bufCycle19[bar_index] = value; break;
      case 19: g_bufCycle20[bar_index] = value; break;
      case 20: g_bufCycle21[bar_index] = value; break;
      case 21: g_bufCycle22[bar_index] = value; break;
      case 22: g_bufCycle23[bar_index] = value; break;
     case 23: g_bufCycle24[bar_index] = value; break;
    }
  }

bool UsesZigZagFeed()
  {
   return (InpFeedMode == Feed_ZigZagHold ||
           InpFeedMode == Feed_ZigZagBridge ||
           InpFeedMode == Feed_ZigZagMidpoint);
  }

void CreateButtons()
  {
   const long chart_id = ChartID();
   int col = 0;
   int row = 0;
   for(int i=0; i<WaveButton_Total; ++i)
     {
      int x = InpButtonX + col * (InpButtonWidth + InpButtonSpacing);
      int y = InpButtonY + row * (InpButtonHeight + InpButtonSpacing);

      const string name = ButtonName(i);
      if(ObjectFind(chart_id, name) >= 0)
         ObjectDelete(chart_id, name);
      if(!ObjectCreate(chart_id, name, OBJ_BUTTON, 0, 0, 0))
         continue;
      ObjectSetInteger(chart_id, name, OBJPROP_CORNER,   InpButtonCorner);
      ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chart_id, name, OBJPROP_XSIZE,     InpButtonWidth);
      ObjectSetInteger(chart_id, name, OBJPROP_YSIZE,     InpButtonHeight);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR,     InpButtonTextColor);
      ObjectSetInteger(chart_id, name, OBJPROP_BGCOLOR,   InpButtonColor);
      ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE,  10);
      ObjectSetString(chart_id,  name, OBJPROP_TEXT,      WAVE_BUTTON_NAMES[i]);

      ++col;
      if(col >= WAVE_BUTTONS_PER_ROW)
        {
         col = 0;
         ++row;
        }
     }
  }

void DestroyButtons()
  {
   const long chart_id = ChartID();
   for(int i=0; i<WaveButton_Total; ++i)
     {
      const string name = ButtonName(i);
      if(ObjectFind(chart_id, name) >= 0)
         ObjectDelete(chart_id, name);
     }
   ObjectDelete(chart_id, WAVE_PRICE_OBJECT);
   ClearDentMarkers();
  }

void UpdateButtons()
  {
   const long chart_id = ChartID();
   for(int i=0; i<WaveButton_Total; ++i)
     {
      const string name = ButtonName(i);
      if(ObjectFind(chart_id, name) < 0)
         continue;
      const bool active = g_buttonState[i];
      ObjectSetInteger(chart_id, name, OBJPROP_BGCOLOR,
                       active ? InpButtonActive : InpButtonColor);
      ObjectSetInteger(chart_id, name, OBJPROP_COLOR, InpButtonTextColor);
     }
  }

void ApplyVisibility()
  {
   PlotIndexSetInteger(0, PLOT_SHOW_DATA, g_buttonState[WaveButton_Wave]);
   PlotIndexSetInteger(1, PLOT_SHOW_DATA, g_buttonState[WaveButton_Noise]);

   for(int i=2; i<=25; ++i)
      PlotIndexSetInteger(i, PLOT_SHOW_DATA, g_buttonState[WaveButton_Cycles]);

   PlotIndexSetInteger(26, PLOT_SHOW_DATA, g_buttonState[WaveButton_Dominant]);
   PlotIndexSetInteger(27, PLOT_SHOW_DATA, g_buttonState[WaveButton_Perfect]);
   PlotIndexSetInteger(28, PLOT_SHOW_DATA, g_buttonState[WaveButton_Countdown]);
  }

void BuildCyclePeriods()
  {
   static const double defaults[24] = {
      18.0, 24.0, 30.0, 36.0, 45.0, 60.0, 75.0, 90.0,
      120.0, 150.0, 180.0, 240.0, 300.0, 360.0, 420.0, 480.0,
      540.0, 600.0, 720.0, 840.0, 960.0, 1080.0, 1260.0, 1440.0
   };
   const int def_count = ArraySize(defaults);
   ArrayResize(g_cyclePeriods, def_count);
   for(int i=0; i<def_count; ++i)
      g_cyclePeriods[i] = defaults[i];

   if(!InpUseManualCycles)
     {
      int limit = (int)MathMax(MathMin((double)InpMaxCandidates, (double)def_count), 0.0);
      if(limit > 0 && limit < def_count)
         ArrayResize(g_cyclePeriods, limit);
      return;
     }

   const int count = (int)MathMax(MathMin((double)InpCycleCount, (double)def_count), 0.0);
   if(count <= 0)
      return;

   ArrayResize(g_cyclePeriods, count);
   const double minP = MathMax(InpCycleMinPeriod, 1.0);
   const double maxP = MathMax(minP, InpCycleMaxPeriod);
   if(count == 1)
     {
      g_cyclePeriods[0] = minP;
      return;
     }

   const double ratio = MathPow(maxP / minP, 1.0 / (count - 1));
   double value = minP;
   for(int i=0; i<count; ++i)
     {
      g_cyclePeriods[i] = value;
      value *= ratio;
     }
  }

bool PrepareFrames()
  {
   if(!BuildPriceSeries())
      return(false);

   if(UsesZigZagFeed())
     {
      if(!EnsureZigZagHandle())
         return(false);
      if(!BuildZigZagSeries(InpFFTWindow))
         return(false);
      ArrayResize(g_frames, InpFFTWindow);
      ArraySetAsSeries(g_frames, false);
      for(int i=0; i<InpFFTWindow; ++i)
         g_frames[i] = g_zigzagSeries[InpFFTWindow-1 - i];
     }
   else
     {
      ArrayResize(g_frames, InpFFTWindow);
      ArrayCopy(g_frames, g_priceSeries, 0, 0, InpFFTWindow);
     }

   const int frame_sanitized = SanitizeBuffer(g_frames);
   if(frame_sanitized > 0 && InpVerboseLog)
      PrintFormat("[WaveViz Solo] Frames sanitizados=%d", frame_sanitized);

   TriangularMovingAverage(g_frames, InpTriangularPeriod, g_measureSeries);
   const int measure_sanitized = SanitizeBuffer(g_measureSeries);
   if(measure_sanitized > 0 && InpVerboseLog)
      PrintFormat("[WaveViz Solo] Measurement sanitizados=%d", measure_sanitized);

   if(InpVerboseLog && ArraySize(g_frames) > 0)
     {
      PrintFormat("[WaveViz Solo] Frame[0]=%.6f Frame[last]=%.6f", g_frames[0], g_frames[ArraySize(g_frames)-1]);
      PrintFormat("[WaveViz Solo] Measurement[0]=%.6f Measurement[last]=%.6f", g_measureSeries[0], g_measureSeries[ArraySize(g_measureSeries)-1]);
     }
   return(true);
  }

bool SubmitJob(const int rates_total)
  {
  if(!g_engine_ready)
    {
     if(InpVerboseLog)
        Print("[WaveViz Solo] Engine não inicializada - SubmitJob abortado");
     GPULog::LogErrorText("submit", "engine_not_ready");
     return false;
    }

   if(!PrepareFrames())
      return false;

   BuildCyclePeriods();

   const ulong tag = ++g_job.tag;
   const int measurement_count = ArraySize(g_measureSeries);
   int cycle_count = (int)MathMin((double)ArraySize(g_cyclePeriods), 24.0);
   if(cycle_count < 0)
      cycle_count = 0;

   uint flags;
   int submit_status = GPU_ENGINE_ERROR;
   ulong handle = 0;

   if(cycle_count > 0)
     {
      flags = JOB_FLAG_STFT | JOB_FLAG_CYCLES;
      submit_status = GpuClient_SubmitJob(g_frames,
                                          1,
                                          g_engine_window,
                                          tag,
                                          flags,
                                          g_gpuEmptyPreviewMask,
                                          InpGaussSigmaPeriod,
                                          InpMaskThreshold,
                                          InpMaskSoftness,
                                          InpMaskMinPeriod,
                                          InpMaskMaxPeriod,
                                          1,
                                          g_cyclePeriods,
                                          cycle_count,
                                          InpCycleWidth,
                                          g_measureSeries,
                                          measurement_count,
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
      flags = JOB_FLAG_STFT;
      submit_status = GpuClient_SubmitJob(g_frames,
                                          1,
                                          g_engine_window,
                                          tag,
                                          flags,
                                          g_gpuEmptyPreviewMask,
                                          InpGaussSigmaPeriod,
                                          InpMaskThreshold,
                                          InpMaskSoftness,
                                          InpMaskMinPeriod,
                                          InpMaskMaxPeriod,
                                          1,
                                          g_gpuEmptyCyclePeriods,
                                          0,
                                          InpCycleWidth,
                                          g_measureSeries,
                                          measurement_count,
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

  if(submit_status != GPU_ENGINE_OK)
    {
     uchar err_buffer[];
     ArrayResize(err_buffer, 512);
     int err_code = GpuClient_GetLastError(err_buffer, ArraySize(err_buffer));
     string err = CharArrayToString(err_buffer, 0, -1);
     GPULog::LogError("submit", submit_status, err);
     if(InpVerboseLog)
        PrintFormat("[WaveViz Solo] SubmitJob falhou (code=%d): %s", err_code, err);
     return false;
    }

  g_job.active         = true;
  g_job.handle         = handle;
  g_job.submitted_bars = rates_total;
  GPULog::LogSubmit(handle,
                    tag,
                    flags,
                    1,
                    g_engine_window,
                    cycle_count,
                    measurement_count,
                    rates_total);
  return true;
  }

void EnsureFetchBuffers(const int frame_total,
                        const int cycle_total,
                        const int cycle_count)
  {
   const int safe_frame_total = (frame_total > 0 ? frame_total : 1);
   const int safe_cycle_total = (cycle_total > 0 ? cycle_total : 1);
   const int safe_cycle_count = (cycle_count > 0 ? cycle_count : 1);
   const int hop = (InpHop > 0 ? InpHop : 1);
   const int estimated_frames = MathMax(1, (safe_frame_total + hop - 1) / hop);
   const int frame_required   = safe_frame_total * estimated_frames;
   const int cycle_required   = safe_cycle_total * estimated_frames;
   const int cycle_list_required = safe_cycle_count * estimated_frames;

   bool ok = true;
   ok = ok && EnsureCapacity(g_waveOut,    frame_required,   "wave_out");
   ok = ok && EnsureCapacity(g_previewOut, frame_required,   "preview_out");
   ok = ok && EnsureCapacity(g_noiseOut,   frame_required,   "noise_out");
   ok = ok && EnsureCapacity(g_cyclesOut,  cycle_required,   "cycles_out");

   ok = ok && EnsureCapacity(g_phaseOut,          frame_required, "phase_out");
   ok = ok && EnsureCapacity(g_phaseUnwrappedOut, frame_required, "phase_unwrapped_out");
   ok = ok && EnsureCapacity(g_amplitudeOut,      frame_required, "amplitude_out");
   ok = ok && EnsureCapacity(g_periodOut,         frame_required, "period_out");
   ok = ok && EnsureCapacity(g_frequencyOut,      frame_required, "frequency_out");
   ok = ok && EnsureCapacity(g_etaOut,            frame_required, "eta_out");
   ok = ok && EnsureCapacity(g_countdownOut,      frame_required, "countdown_out");
   ok = ok && EnsureCapacity(g_reconOut,          frame_required, "recon_out");
   ok = ok && EnsureCapacity(g_kalmanOut,         frame_required, "kalman_out");
   ok = ok && EnsureCapacity(g_confidenceOut,     frame_required, "confidence_out");
   ok = ok && EnsureCapacity(g_ampDeltaOut,       frame_required, "amp_delta_out");
   ok = ok && EnsureCapacity(g_turnOut,           frame_required, "turn_out");
   ok = ok && EnsureCapacity(g_directionOut,      frame_required, "direction_out");
   ok = ok && EnsureCapacity(g_powerOut,          frame_required, "power_out");
   ok = ok && EnsureCapacity(g_velocityOut,       frame_required, "velocity_out");

   ok = ok && EnsureCapacity(g_phaseAllOut,          cycle_required, "phase_all_out");
   ok = ok && EnsureCapacity(g_phaseUnwrappedAllOut, cycle_required, "phase_unwrapped_all_out");
   ok = ok && EnsureCapacity(g_amplitudeAllOut,      cycle_required, "amplitude_all_out");
   ok = ok && EnsureCapacity(g_periodAllOut,         cycle_required, "period_all_out");
   ok = ok && EnsureCapacity(g_frequencyAllOut,      cycle_required, "frequency_all_out");
   ok = ok && EnsureCapacity(g_etaAllOut,            cycle_required, "eta_all_out");
   ok = ok && EnsureCapacity(g_countdownAllOut,      cycle_required, "countdown_all_out");
   ok = ok && EnsureCapacity(g_directionAllOut,      cycle_required, "direction_all_out");
   ok = ok && EnsureCapacity(g_reconAllOut,          cycle_required, "recon_all_out");
   ok = ok && EnsureCapacity(g_kalmanAllOut,         cycle_required, "kalman_all_out");
   ok = ok && EnsureCapacity(g_turnAllOut,           cycle_required, "turn_all_out");
   ok = ok && EnsureCapacity(g_confidenceAllOut,     cycle_required, "confidence_all_out");
   ok = ok && EnsureCapacity(g_ampDeltaAllOut,       cycle_required, "amp_delta_all_out");
   ok = ok && EnsureCapacity(g_powerAllOut,          cycle_required, "power_all_out");
   ok = ok && EnsureCapacity(g_velocityAllOut,       cycle_required, "velocity_all_out");

   ok = ok && EnsureCapacity(g_plvCyclesOut, cycle_list_required, "plv_cycles_out");
   ok = ok && EnsureCapacity(g_snrCyclesOut, cycle_list_required, "snr_cycles_out");

   if(!ok && InpVerboseLog)
      Print("[WaveViz Solo] Aviso: redimensionamento de buffers falhou");

   ArrayResize(g_bufPerfect,   safe_frame_total);
   ArrayResize(g_bufCountdown, safe_frame_total);
  }

void CopyResultsToBuffers(const GpuEngineResultInfo &info)
  {
   const int frame_length = info.frame_length;
   const int frame_count  = info.frame_count;
   if(frame_length <= 0 || frame_count <= 0)
      return;

   ClearCycleBuffers();
   ArrayInitialize(g_bufDominant, EMPTY_VALUE);
   ArrayInitialize(g_bufPerfect,  EMPTY_VALUE);
   ArrayInitialize(g_bufCountdown,EMPTY_VALUE);

   const int capacity_wave = ArraySize(g_waveOut);
   const int max_frames_supported = (frame_length > 0 ? capacity_wave / frame_length : 0);
   int latest_offset = 0;
   if(max_frames_supported <= 0)
     {
      if(InpVerboseLog)
         Print("[WaveViz Solo] Nenhuma capacidade para wave_out");
      return;
     }

   if(frame_count > max_frames_supported)
     {
      if(InpVerboseLog)
         PrintFormat("[WaveViz Solo] frame_count=%d truncado para %d", frame_count, max_frames_supported);
      latest_offset = (max_frames_supported - 1) * frame_length;
     }
   else
     {
      latest_offset = (frame_count - 1) * frame_length;
     }

   if(latest_offset + frame_length > capacity_wave)
     {
      if(InpVerboseLog)
         PrintFormat("[WaveViz Solo] Capacidade insuficiente: offset=%d len=%d cap=%d", latest_offset, frame_length, capacity_wave);
      return;
     }

   for(int i=0; i<frame_length; ++i)
     {
      const int src = latest_offset + (frame_length - 1 - i);

      g_bufWave[i] = (g_buttonState[WaveButton_Wave] && src < ArraySize(g_waveOut)) ? g_waveOut[src] : EMPTY_VALUE;
      g_bufNoise[i] = (g_buttonState[WaveButton_Noise] && src < ArraySize(g_noiseOut)) ? g_noiseOut[src] : EMPTY_VALUE;
      if(g_buttonState[WaveButton_Perfect] && src < ArraySize(g_reconOut))
         g_bufPerfect[i] = g_reconOut[src];
      if(g_buttonState[WaveButton_Countdown] && src < ArraySize(g_countdownOut))
         g_bufCountdown[i] = g_countdownOut[src];
     }

   if(g_buttonState[WaveButton_Dominant] && info.dominant_cycle >= 0 && info.dominant_cycle < info.cycle_count)
     {
      const int dominant_base = info.dominant_cycle * frame_length + latest_offset;
      for(int i=0; i<frame_length; ++i)
        {
         const int src_index = dominant_base + (frame_length - 1 - i);
         if(src_index >= 0 && src_index < ArraySize(g_cyclesOut))
            g_bufDominant[i] = g_cyclesOut[src_index];
       }
    }

   if(!g_buttonState[WaveButton_Cycles] || info.cycle_count <= 0)
     return;

   const int cycle_count = MathMin(info.cycle_count, 24);
   const int selected_count = MathMin(WAVE_TOP_CYCLES, cycle_count);
   int selected[];
   ArrayResize(selected, WAVE_TOP_CYCLES);
   ArrayInitialize(selected, -1);

   if(ArraySize(g_plvCyclesOut) >= cycle_count)
     {
      bool used[];
      ArrayResize(used, 24);
      ArrayInitialize(used, false);
      for(int k=0; k<selected_count; ++k)
        {
         double best = -DBL_MAX;
         int best_idx = -1;
         for(int c=0; c<cycle_count; ++c)
           {
            if(used[c])
               continue;
            double plv = g_plvCyclesOut[c];
            if(plv > best)
              {
               best = plv;
               best_idx = c;
              }
           }
         if(best_idx < 0)
            break;
         selected[k] = best_idx;
         used[best_idx] = true;
        }
     }
   else
     {
      for(int k=0; k<selected_count; ++k)
         selected[k] = k;
     }

   for(int s=0; s<selected_count; ++s)
     {
      const int idx = selected[s];
      if(idx < 0)
         continue;
      const int cycle_base = latest_offset + idx * frame_length;
      for(int i=0; i<frame_length; ++i)
        {
         const int src_index = cycle_base + (frame_length - 1 - i);
         const double value = (src_index >= 0 && src_index < ArraySize(g_cyclesOut)) ? g_cyclesOut[src_index] : EMPTY_VALUE;
         SetCycleValue(idx, i, value);
        }
     }

   if(InpVerboseLog)
     {
      const int sample_index = latest_offset + (frame_length - 1);
      double wave_sample = (sample_index >= 0 && sample_index < ArraySize(g_waveOut)) ? g_waveOut[sample_index] : EMPTY_VALUE;
      double noise_sample = (sample_index >= 0 && sample_index < ArraySize(g_noiseOut)) ? g_noiseOut[sample_index] : EMPTY_VALUE;
      double price_sample = (ArraySize(g_priceSeries) > 0 ? g_priceSeries[ArraySize(g_priceSeries) - 1] : EMPTY_VALUE);
      double wave_min = DBL_MAX;
      double wave_max = -DBL_MAX;
      double noise_min = DBL_MAX;
      double noise_max = -DBL_MAX;
      double meas_min = DBL_MAX;
      double meas_max = -DBL_MAX;
      for(int i=0; i<frame_length; ++i)
        {
         const int src = latest_offset + i;
         if(src >= 0 && src < ArraySize(g_waveOut))
           {
            const double v = g_waveOut[src];
            if(!IsBadSample(v))
              {
               wave_min = MathMin(wave_min, v);
               wave_max = MathMax(wave_max, v);
              }
           }
         if(src >= 0 && src < ArraySize(g_noiseOut))
           {
            const double v = g_noiseOut[src];
            if(!IsBadSample(v))
              {
               noise_min = MathMin(noise_min, v);
               noise_max = MathMax(noise_max, v);
              }
           }
         if(src >= 0 && src < ArraySize(g_measureSeries))
           {
            const double v = g_measureSeries[src];
            if(!IsBadSample(v))
              {
               meas_min = MathMin(meas_min, v);
               meas_max = MathMax(meas_max, v);
              }
           }
        }
      PrintFormat("[WaveViz Solo] Sample wave=%.6f noise=%.6f price=%.6f diff=%.6f wave_range=[%.6f, %.6f] noise_range=[%.6f, %.6f] frames=%d len=%d cap=%d",
                  wave_sample,
                  noise_sample,
                  price_sample,
                  (wave_sample != EMPTY_VALUE && price_sample != EMPTY_VALUE) ? wave_sample - price_sample : EMPTY_VALUE,
                  (wave_min == DBL_MAX ? EMPTY_VALUE : wave_min),
                  (wave_max == -DBL_MAX ? EMPTY_VALUE : wave_max),
                  (noise_min == DBL_MAX ? EMPTY_VALUE : noise_min),
                  (noise_max == -DBL_MAX ? EMPTY_VALUE : noise_max),
                  frame_count,
                  frame_length,
                  ArraySize(g_waveOut));
      PrintFormat("[WaveViz Solo] Measurement_range=[%.6f, %.6f]", (meas_min == DBL_MAX ? EMPTY_VALUE : meas_min), (meas_max == -DBL_MAX ? EMPTY_VALUE : meas_max));
     }
  }

bool FetchCurrentResult()
  {
   if(!g_engine_ready || !g_job.active)
      return false;

  int status = GPU_ENGINE_IN_PROGRESS;
  const int poll_status = GpuClient_PollStatus(g_job.handle, status);
  if(poll_status != GPU_ENGINE_OK)
    {
     GPULog::LogError("poll", poll_status, "GpuClient_PollStatus");
     return false;
    }
  GPULog::LogPoll(g_job.handle, status);

   if(status != GPU_ENGINE_READY)
      return false;

   EnsureFetchBuffers(InpFFTWindow,
                      InpFFTWindow * MathMax(ArraySize(g_cyclePeriods), 1),
                      MathMax(ArraySize(g_cyclePeriods), 1));

   int fetch_status = GpuClient_FetchResult(g_job.handle,
                                            g_waveOut,
                                            g_previewOut,
                                            g_cyclesOut,
                                            g_noiseOut,
                                            g_phaseOut,
                                            g_phaseUnwrappedOut,
                                            g_amplitudeOut,
                                            g_periodOut,
                                            g_frequencyOut,
                                            g_etaOut,
                                            g_countdownOut,
                                            g_reconOut,
                                            g_kalmanOut,
                                            g_confidenceOut,
                                            g_ampDeltaOut,
                                            g_turnOut,
                                            g_directionOut,
                                            g_powerOut,
                                            g_velocityOut,
                                            g_phaseAllOut,
                                            g_phaseUnwrappedAllOut,
                                            g_amplitudeAllOut,
                                            g_periodAllOut,
                                            g_frequencyAllOut,
                                            g_etaAllOut,
                                            g_countdownAllOut,
                                            g_directionAllOut,
                                            g_reconAllOut,
                                            g_kalmanAllOut,
                                            g_turnAllOut,
                                            g_confidenceAllOut,
                                            g_ampDeltaAllOut,
                                            g_powerAllOut,
                                            g_velocityAllOut,
                                            g_plvCyclesOut,
                                            g_snrCyclesOut,
                                            g_lastInfo);
  if(fetch_status != GPU_ENGINE_OK)
    {
     uchar err_buffer[];
     ArrayResize(err_buffer, 512);
     int err_code = GpuClient_GetLastError(err_buffer, ArraySize(err_buffer));
     string err = CharArrayToString(err_buffer, 0, -1);
     GPULog::LogError("fetch", fetch_status, err);
     if(InpVerboseLog)
        PrintFormat("[WaveViz Solo] FetchResult falhou (code=%d): %s", err_code, err);
     g_job.active = false;
     return false;
    }

  CopyResultsToBuffers(g_lastInfo);
  GPULog::LogFetch(g_job.handle, g_lastInfo);

   const double wave_now     = (ArraySize(g_waveOut) > 0 ? g_waveOut[ArraySize(g_waveOut)-1] : 0.0);
   const double perfect_now  = (ArraySize(g_reconOut) > 0 ? g_reconOut[ArraySize(g_reconOut)-1] : wave_now);
   const double countdown_now= (ArraySize(g_countdownOut) > 0 ? g_countdownOut[ArraySize(g_countdownOut)-1] : 0.0);

   g_statusText = StringFormat("Wave %.5f | Perfect %.5f | Cycle #%d (%.1f) PLV=%.3f | Countdown=%.1f",
                               wave_now,
                               perfect_now,
                               g_lastInfo.dominant_cycle,
                               g_lastInfo.dominant_period,
                               g_lastInfo.dominant_plv,
                               countdown_now);

   g_lastOverlayTag = 0;
  g_lastMarkerTag  = 0;

   g_job.active = false;
   return(true);
  }

void ClearDentMarkers()
  {
   const long chart_id = ChartID();
   const int total = ObjectsTotal(chart_id, 0, -1);
   for(int i=total-1; i>=0; --i)
     {
      const string name = ObjectName(chart_id, i);
      if(StringFind(name, WAVE_MARKER_PREFIX, 0) == 0)
         ObjectDelete(chart_id, name);
     }
  }

void RefreshPriceOverlay(const datetime &time[], const double &close[], const int rates_total)
  {
   const long chart_id = ChartID();

#ifdef GPU_WAVE_POLYLINE_SUPPORT
   if(!g_buttonState[WaveButton_Perfect])
     {
      ObjectDelete(chart_id, WAVE_PRICE_OBJECT);
      return;
     }

   if(g_lastInfo.frame_length <= 0 || g_lastInfo.frame_count <= 0)
      return;

   if(g_lastOverlayTag == g_lastInfo.user_tag)
      return;

   const int frame_length = g_lastInfo.frame_length;
   const int frame_count  = g_lastInfo.frame_count;
   const int latest_offset = (frame_count - 1) * frame_length;
   const int available_bars = MathMin(frame_length, rates_total);
   const int max_points = MathMin(available_bars, WAVE_MAX_OVERLAY_POINTS);
   if(max_points < 2)
      return;

   if(ObjectFind(chart_id, WAVE_PRICE_OBJECT) < 0)
     {
      if(!ObjectCreate(chart_id, WAVE_PRICE_OBJECT, OBJ_POLYLINE, 0, 0, 0))
         return;
      ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_COLOR, clrRoyalBlue);
      ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_WIDTH, 2);
      ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_HIDDEN, true);
     }

   ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_POINTS, max_points);

   const int start_src = latest_offset + (frame_length - max_points);
   for(int i=0; i<max_points; ++i)
     {
      const int src = start_src + i;
      const int series_index = max_points - 1 - i;
      datetime t = time[series_index];
      double price = (src >= 0 && src < ArraySize(g_reconOut)) ? g_reconOut[src] : close[series_index];
      ObjectSetInteger(chart_id, WAVE_PRICE_OBJECT, OBJPROP_TIME,  i, t);
      ObjectSetDouble (chart_id, WAVE_PRICE_OBJECT, OBJPROP_PRICE, i, price);
     }

   g_lastOverlayTag = g_lastInfo.user_tag;
#else
   ObjectDelete(chart_id, WAVE_PRICE_OBJECT);
#endif
  }

void RefreshDentMarkers(const datetime &time[], const double &close[], const int rates_total)
  {
   const long chart_id = ChartID();

#ifdef GPU_WAVE_MARKER_SUPPORT
   if(!g_buttonState[WaveButton_Markers])
     {
      ClearDentMarkers();
      return;
     }

   if(g_lastInfo.frame_length <= 0 || g_lastInfo.frame_count <= 0)
      return;

   if(g_lastMarkerTag == g_lastInfo.user_tag)
      return;

   ClearDentMarkers();

   const int frame_length = g_lastInfo.frame_length;
   const int frame_count  = g_lastInfo.frame_count;
   const int latest_offset = (frame_count - 1) * frame_length;
   const int available_bars = MathMin(frame_length, rates_total);
   const int max_points = MathMin(available_bars, WAVE_MAX_OVERLAY_POINTS);
   if(max_points < 2)
      return;

   int markers = 0;
   const int start_src = latest_offset + (frame_length - max_points);
   for(int i=0; i<max_points && markers < WAVE_MAX_MARKERS; ++i)
     {
      const int src = start_src + i;
      if(src < 0 || src >= ArraySize(g_turnOut))
         continue;

      const double turn = g_turnOut[src];
      const double countdown = (src < ArraySize(g_countdownOut) ? g_countdownOut[src] : EMPTY_VALUE);
      const bool strong_turn = (turn != EMPTY_VALUE && MathAbs(turn) > 0.25);
      const bool countdown_zero = (countdown != EMPTY_VALUE && MathAbs(countdown) <= 0.5);
      if(!strong_turn && !countdown_zero)
         continue;

      const int series_index = max_points - 1 - i;
      const datetime t = time[series_index];
      const double price = close[series_index];
      const string name = WAVE_MARKER_PREFIX + IntegerToString(markers);

      if(ObjectCreate(chart_id, name, OBJ_ARROW, 0, t, price))
        {
         const int arrow = strong_turn && turn < 0 ? SYMBOL_ARROWDOWN : SYMBOL_ARROWUP;
         ObjectSetInteger(chart_id, name, OBJPROP_ARROWCODE, arrow);
         ObjectSetInteger(chart_id, name, OBJPROP_COLOR, strong_turn ? clrOrangeRed : clrDodgerBlue);
         ObjectSetInteger(chart_id, name, OBJPROP_WIDTH,  1);
         ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN,      true);
         ++markers;
        }
     }

   g_lastMarkerTag = g_lastInfo.user_tag;
#else
   ClearDentMarkers();
#endif
  }

void UpdateHudText()
  {
   if(!g_buttonState[WaveButton_Hud])
     {
      Comment("");
      return;
     }

   string hud = g_statusText;
   if(StringLen(g_backendSummary) > 0)
     {
      if(StringLen(hud) > 0)
         hud = g_backendSummary + "\n" + hud;
      else
         hud = g_backendSummary;
     }
   Comment(hud);
  }

int OnInit()
  {
   const bool tester_mode = (MQLInfoInteger(MQL_TESTER) != 0);
   bool use_service = true;
   if(!tester_mode && !InpUseGpuService)
      Print("[WaveViz Solo] UseGpuService ignorado (serviço obrigatório nesta build).");

   SetIndexBuffer(0, g_bufWave,      INDICATOR_DATA);
   SetIndexBuffer(1, g_bufNoise,     INDICATOR_DATA);
   SetIndexBuffer(2, g_bufCycle1,    INDICATOR_DATA);
   SetIndexBuffer(3, g_bufCycle2,    INDICATOR_DATA);
   SetIndexBuffer(4, g_bufCycle3,    INDICATOR_DATA);
   SetIndexBuffer(5, g_bufCycle4,    INDICATOR_DATA);
   SetIndexBuffer(6, g_bufCycle5,    INDICATOR_DATA);
   SetIndexBuffer(7, g_bufCycle6,    INDICATOR_DATA);
   SetIndexBuffer(8, g_bufCycle7,    INDICATOR_DATA);
   SetIndexBuffer(9, g_bufCycle8,    INDICATOR_DATA);
   SetIndexBuffer(10,g_bufCycle9,    INDICATOR_DATA);
   SetIndexBuffer(11,g_bufCycle10,   INDICATOR_DATA);
   SetIndexBuffer(12,g_bufCycle11,   INDICATOR_DATA);
   SetIndexBuffer(13,g_bufCycle12,   INDICATOR_DATA);
   SetIndexBuffer(14,g_bufCycle13,   INDICATOR_DATA);
   SetIndexBuffer(15,g_bufCycle14,   INDICATOR_DATA);
   SetIndexBuffer(16,g_bufCycle15,   INDICATOR_DATA);
   SetIndexBuffer(17,g_bufCycle16,   INDICATOR_DATA);
   SetIndexBuffer(18,g_bufCycle17,   INDICATOR_DATA);
   SetIndexBuffer(19,g_bufCycle18,   INDICATOR_DATA);
   SetIndexBuffer(20,g_bufCycle19,   INDICATOR_DATA);
   SetIndexBuffer(21,g_bufCycle20,   INDICATOR_DATA);
   SetIndexBuffer(22,g_bufCycle21,   INDICATOR_DATA);
   SetIndexBuffer(23,g_bufCycle22,   INDICATOR_DATA);
   SetIndexBuffer(24,g_bufCycle23,   INDICATOR_DATA);
   SetIndexBuffer(25,g_bufCycle24,   INDICATOR_DATA);
   SetIndexBuffer(26,g_bufDominant,  INDICATOR_DATA);
   SetIndexBuffer(27,g_bufPerfect,   INDICATOR_DATA);
   SetIndexBuffer(28,g_bufCountdown, INDICATOR_DATA);

   ArraySetAsSeries(g_bufWave,      true);
   ArraySetAsSeries(g_bufNoise,     true);
   ArraySetAsSeries(g_bufCycle1,    true);
   ArraySetAsSeries(g_bufCycle2,    true);
   ArraySetAsSeries(g_bufCycle3,    true);
   ArraySetAsSeries(g_bufCycle4,    true);
   ArraySetAsSeries(g_bufCycle5,    true);
   ArraySetAsSeries(g_bufCycle6,    true);
   ArraySetAsSeries(g_bufCycle7,    true);
   ArraySetAsSeries(g_bufCycle8,    true);
   ArraySetAsSeries(g_bufCycle9,    true);
   ArraySetAsSeries(g_bufCycle10,   true);
   ArraySetAsSeries(g_bufCycle11,   true);
   ArraySetAsSeries(g_bufCycle12,   true);
   ArraySetAsSeries(g_bufCycle13,   true);
   ArraySetAsSeries(g_bufCycle14,   true);
   ArraySetAsSeries(g_bufCycle15,   true);
   ArraySetAsSeries(g_bufCycle16,   true);
   ArraySetAsSeries(g_bufCycle17,   true);
   ArraySetAsSeries(g_bufCycle18,   true);
   ArraySetAsSeries(g_bufCycle19,   true);
   ArraySetAsSeries(g_bufCycle20,   true);
   ArraySetAsSeries(g_bufCycle21,   true);
   ArraySetAsSeries(g_bufCycle22,   true);
   ArraySetAsSeries(g_bufCycle23,   true);
   ArraySetAsSeries(g_bufCycle24,   true);
   ArraySetAsSeries(g_bufDominant,  true);
   ArraySetAsSeries(g_bufPerfect,   true);
   ArraySetAsSeries(g_bufCountdown, true);

   ArrayInitialize(g_bufWave,      EMPTY_VALUE);
   ArrayInitialize(g_bufNoise,     EMPTY_VALUE);
   ArrayInitialize(g_bufPerfect,   EMPTY_VALUE);
   ArrayInitialize(g_bufCountdown, EMPTY_VALUE);
   ClearCycleBuffers();

   g_buttonState[WaveButton_Wave]      = true;
   g_buttonState[WaveButton_Noise]     = true;
   g_buttonState[WaveButton_Perfect]   = true;
   g_buttonState[WaveButton_Dominant]  = true;
   g_buttonState[WaveButton_Cycles]    = true;
   g_buttonState[WaveButton_Countdown] = false;
   g_buttonState[WaveButton_Markers]   = true;
   g_buttonState[WaveButton_Hud]       = true;

   CreateButtons();
   UpdateButtons();
   ApplyVisibility();

   IndicatorSetString(INDICATOR_SHORTNAME, "GPU WaveViz Solo");

   g_prevLogging = GpuLogsEnabled();
   GpuSetLogging(InpVerboseLog);
   GPULog::Init("WaveVizSolo", true, InpVerboseLog);
   GPULog::SetDebug(InpVerboseLog);

   if(UsesZigZagFeed())
     {
      if(!EnsureZigZagHandle())
         return INIT_FAILED;
     }

   g_engine_ready  = false;
   g_engine_window = InpFFTWindow;

   int init_status = GpuClient_Open(InpGPUDevice,
                                   InpFFTWindow,
                                   InpHop,
                                   1,
                                   false,
                                   use_service,
                                   tester_mode);
   if(init_status != GPU_ENGINE_OK)
     {
      uchar err_buffer[];
      ArrayResize(err_buffer, 512);
      int err_code = GpuClient_GetLastError(err_buffer, ArraySize(err_buffer));
      string err = CharArrayToString(err_buffer, 0, -1);
      GPULog::LogError("open", init_status, err);
      PrintFormat("[WaveViz Solo] Falha ao inicializar a GPU Engine (code=%d): %s", err_code, err);
      return INIT_FAILED;
     }

   g_engine_ready = true;

   uchar backend_buffer[];
   ArrayResize(backend_buffer, 64);
   int backend_len = GpuClient_GetBackendName(backend_buffer, ArraySize(backend_buffer));
   string backend_name = (backend_len > 0) ? CharArrayToString(backend_buffer, 0, backend_len)
                                           : (GpuClient_IsServiceBackend() != 0 ? "service" : (tester_mode ? "tester" : "dll"));
   string backend_desc;
   if(backend_name == "service")
      backend_desc = "serviço (GpuEngineService)";
   else if(backend_name == "tester")
      backend_desc = "DLL dedicada ao Strategy Tester";
  else
     backend_desc = "DLL direta";
  g_backendSummary = "Backend: " + backend_desc;
  GPULog::LogOpen(InpGPUDevice,
                  InpFFTWindow,
                  InpHop,
                  1,
                  use_service,
                  tester_mode,
                  backend_name);
  Print("[WaveViz Solo] " + g_backendSummary);

   BuildCyclePeriods();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_backendSummary = "";
   if(g_zigzagHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_zigzagHandle);
      g_zigzagHandle = INVALID_HANDLE;
     }
   if(g_engine_ready)
     {
      GpuClient_Close();
      g_engine_ready = false;
      GPULog::LogClose();
     }
   GpuSetLogging(g_prevLogging);
   DestroyButtons();
   Comment("");
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   const int idx = FindButtonIndex(sparam);
   if(idx < 0)
      return;

   g_buttonState[idx] = !g_buttonState[idx];
   UpdateButtons();
   ApplyVisibility();

   if(idx == WaveButton_Perfect)
      g_lastOverlayTag = 0;
   if(idx == WaveButton_Markers)
      g_lastMarkerTag = 0;

   if(g_lastInfo.frame_length > 0)
      CopyResultsToBuffers(g_lastInfo);

   ChartRedraw(ChartID());
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < InpFFTWindow)
      return(prev_calculated);

   if(g_job.active)
      FetchCurrentResult();

   if(!g_job.active && g_job.submitted_bars != rates_total)
     {
      if(SubmitJob(rates_total))
         FetchCurrentResult();
     }

   UpdateHudText();
   RefreshPriceOverlay(time, close, rates_total);
   RefreshDentMarkers(time, close, rates_total);

   return(rates_total);
  }
