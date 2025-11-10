//+------------------------------------------------------------------+
//| GPU_PhaseViz_Solo.mq5                                            |
//| Visualização autônoma da fase principal da WaveSpec GPU.         |
//| Inclui HUD dinâmico, sobreposição no gráfico principal           |
//| (linha colada no preço) e marcadores de "dente"/countdown.       |
//+------------------------------------------------------------------+
#property copyright   "2025"
#property version     "2.000"
#property strict

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8

#property indicator_label1  "Phase"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_width1  2

#property indicator_label2  "PhaseSaw"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDeepSkyBlue

#property indicator_label3  "Amplitude"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue

#property indicator_label4  "Kalman"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLawnGreen
#property indicator_width4  2

#property indicator_label5  "Countdown"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrTomato

#property indicator_label6  "TurnPulse"
#property indicator_type6   DRAW_HISTOGRAM
#property indicator_color6  clrOrangeRed
#property indicator_width6  2

#property indicator_label7  "Frequency"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrViolet

#property indicator_label8  "Velocity"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrChocolate

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
   GPU_ENGINE_ERROR       = -1
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
#define GPU_SANITIZE_THRESHOLD 1.0e12

bool IsBadSample(const double value)
  {
   if(!MathIsValidNumber(value))
      return true;
   if(value == EMPTY_VALUE || value == DBL_MAX || value == -DBL_MAX)
      return true;
   if(MathAbs(value) >= GPU_SANITIZE_THRESHOLD)
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

bool UsesZigZagFeed()
  {
   return (InpFeedMode == Feed_ZigZagHold ||
           InpFeedMode == Feed_ZigZagBridge ||
           InpFeedMode == Feed_ZigZagMidpoint);
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
      PrintFormat("[PhaseViz Solo] Falha ao inicializar ZigZag (depth=%d deviation=%d backstep=%d)",
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
         PrintFormat("[PhaseViz Solo] ZigZag insuficiente (%d/%d)", copied, samples_needed);
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

bool PrepareZigZagFrames()
  {
   if(!UsesZigZagFeed())
      return false;
   if(!EnsureZigZagHandle())
      return false;

   if(!BuildZigZagSeries(InpFFTWindow))
      return false;

   ArrayResize(g_frames, InpFFTWindow);
   ArraySetAsSeries(g_frames, false);
   for(int i=0; i<InpFFTWindow; ++i)
      g_frames[i] = g_zigzagSeries[InpFFTWindow-1 - i];
   return true;
  }

#ifdef OBJ_POLYLINE
   #ifdef OBJPROP_POINTS
      #define GPU_PHASE_POLYLINE_SUPPORT
   #endif
#endif

#ifdef OBJ_ARROW
   #ifdef OBJPROP_ARROWCODE
      #define GPU_PHASE_MARKER_SUPPORT
   #endif
#endif

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

enum PhaseButton
  {
   PhaseButton_Phase = 0,
   PhaseButton_PhaseSaw,
   PhaseButton_Amplitude,
   PhaseButton_Kalman,
   PhaseButton_Countdown,
   PhaseButton_Turn,
   PhaseButton_Frequency,
   PhaseButton_Velocity,
   PhaseButton_PriceLine,
   PhaseButton_Markers,
   PhaseButton_Hud,
   PhaseButton_Total
  };

input bool         InpVerboseLog      = true;
input int          InpGPUDevice       = 0;
input int          InpFFTWindow       = 4096;
input int          InpHop             = 1024;
input bool         InpUseManualCycles = false;
input int          InpCycleCount      = 24;
input double       InpCycleMinPeriod  = 18.0;
input double       InpCycleMaxPeriod  = 1440.0;
input double       InpCycleWidth      = 0.25;
input int          InpMaxCandidates   = 24;
input double       InpGaussSigmaPeriod       = 48.0;
input double       InpMaskThreshold   = 0.05;
input double       InpMaskSoftness    = 0.20;
input double       InpMaskMinPeriod   = 18.0;
input double       InpMaskMaxPeriod   = 512.0;
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
input int   InpButtonWidth     = 110;
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
         PrintFormat("[PhaseViz Solo] Falha ao redimensionar %s para %d", name, required);
      return false;
     }
   return true;
  }

const uint JOB_FLAG_STFT   = 1;
const uint JOB_FLAG_CYCLES = 2;

//--- indicator buffers
double g_bufPhase[];
double g_bufPhaseSaw[];
double g_bufAmplitudeLine[];
double g_bufKalmanLine[];
double g_bufCountdownLine[];
double g_bufTurnPulse[];
double g_bufFrequencyLine[];
double g_bufVelocityLine[];

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
double g_directionOut[];
double g_turnOut[];
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

//--- UI/state helpers
const string PHASE_BUTTON_NAMES[PhaseButton_Total] = {
   "Phase",
   "PhaseSaw",
   "Amplitude",
   "Kalman",
   "Countdown",
   "Dent",
   "Frequency",
   "Velocity",
   "PriceLine",
   "Markers",
   "HUD"
};

const string PHASE_BUTTON_PREFIX = "gpu_phase_solo_btn_";
const string PHASE_PRICE_OBJECT  = "gpu_phase_price_overlay";
const string PHASE_MARKER_PREFIX = "gpu_phase_marker_";
const int    PHASE_BUTTONS_PER_ROW = 6;
const int    PHASE_MAX_OVERLAY_POINTS = 512;
const int    PHASE_MAX_MARKERS       = 20;

bool   g_buttonState[PhaseButton_Total];
string g_statusText = "";
string g_backendSummary = "";
ulong  g_lastOverlayTag = 0;
ulong  g_lastMarkerTag  = 0;

bool g_engine_ready = false;
bool g_prevLogging  = true;
int  g_engine_window = 0;

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
int    FindButtonIndex(const string &name);
string ButtonName(const int index);
void   ClearOutputBuffers();
void   BuildCyclePeriods();
bool   BuildPriceSeries();
bool   PrepareFrames();
bool   SubmitJob(const int rates_total);
bool   FetchCurrentResult();
void   EnsureFetchBuffers();
void   CopyResultsToBuffers(const GpuEngineResultInfo &info);
void   CreateButtons();
void   DestroyButtons();
void   UpdateButtons();
void   ApplyVisibility();
void   UpdateHudText();
void   RefreshPriceOverlay(const datetime &time[], const double &close[], const int rates_total);
void   RefreshDentMarkers(const datetime &time[], const double &close[], const int rates_total);
void   ClearDentMarkers();

//--- utility -------------------------------------------------------
int FindButtonIndex(const string &name)
  {
   for(int i=0; i<PhaseButton_Total; ++i)
      if(name == ButtonName(i))
         return i;
   return -1;
  }

string ButtonName(const int index)
  {
   return PHASE_BUTTON_PREFIX + PHASE_BUTTON_NAMES[index];
  }

void ClearOutputBuffers()
  {
   ArrayInitialize(g_bufPhase,         EMPTY_VALUE);
   ArrayInitialize(g_bufPhaseSaw,      EMPTY_VALUE);
   ArrayInitialize(g_bufAmplitudeLine, EMPTY_VALUE);
   ArrayInitialize(g_bufKalmanLine,    EMPTY_VALUE);
   ArrayInitialize(g_bufCountdownLine, EMPTY_VALUE);
   ArrayInitialize(g_bufTurnPulse,     EMPTY_VALUE);
   ArrayInitialize(g_bufFrequencyLine, EMPTY_VALUE);
   ArrayInitialize(g_bufVelocityLine,  EMPTY_VALUE);
  }

//--- button helpers ------------------------------------------------
void CreateButtons()
  {
   const long chart_id = ChartID();
   int col = 0;
   int row = 0;
   for(int i=0; i<PhaseButton_Total; ++i)
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
      ObjectSetString(chart_id,  name, OBJPROP_TEXT,      PHASE_BUTTON_NAMES[i]);

      ++col;
      if(col >= PHASE_BUTTONS_PER_ROW)
        {
         col = 0;
         ++row;
        }
     }
  }

void DestroyButtons()
  {
   const long chart_id = ChartID();
   for(int i=0; i<PhaseButton_Total; ++i)
     {
      const string name = ButtonName(i);
      if(ObjectFind(chart_id, name) >= 0)
         ObjectDelete(chart_id, name);
     }
   ObjectDelete(chart_id, PHASE_PRICE_OBJECT);
   ClearDentMarkers();
  }

void UpdateButtons()
  {
   const long chart_id = ChartID();
   for(int i=0; i<PhaseButton_Total; ++i)
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
   const int plotStates[8] = {
      g_buttonState[PhaseButton_Phase],
      g_buttonState[PhaseButton_PhaseSaw],
      g_buttonState[PhaseButton_Amplitude],
      g_buttonState[PhaseButton_Kalman],
      g_buttonState[PhaseButton_Countdown],
      g_buttonState[PhaseButton_Turn],
      g_buttonState[PhaseButton_Frequency],
      g_buttonState[PhaseButton_Velocity]
   };
   for(int i=0; i<8; ++i)
      PlotIndexSetInteger(i, PLOT_SHOW_DATA, plotStates[i]);
  }

//--- data preparation ----------------------------------------------
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
      PrintFormat("[PhaseViz Solo] Price sanitizados=%d", sanitized);
   return(true);
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

bool PrepareFrames()
  {
   if(!BuildPriceSeries())
      return(false);

   if(UsesZigZagFeed())
     {
      if(!PrepareZigZagFrames())
         return(false);
     }
   else
     {
      ArrayResize(g_frames, InpFFTWindow);
      ArrayCopy(g_frames, g_priceSeries, 0, 0, InpFFTWindow);
     }

   const int frame_sanitized = SanitizeBuffer(g_frames);
   if(frame_sanitized > 0 && InpVerboseLog)
      PrintFormat("[PhaseViz Solo] Frames sanitizados=%d", frame_sanitized);

   TriangularMovingAverage(g_frames, InpTriangularPeriod, g_measureSeries);
   const int measure_sanitized = SanitizeBuffer(g_measureSeries);
   if(measure_sanitized > 0 && InpVerboseLog)
      PrintFormat("[PhaseViz Solo] Measurement sanitizados=%d", measure_sanitized);

   if(InpVerboseLog && ArraySize(g_frames) > 0)
     {
      PrintFormat("[PhaseViz Solo] Frame[0]=%.6f Frame[last]=%.6f", g_frames[0], g_frames[ArraySize(g_frames)-1]);
      PrintFormat("[PhaseViz Solo] Measurement[0]=%.6f Measurement[last]=%.6f", g_measureSeries[0], g_measureSeries[ArraySize(g_measureSeries)-1]);
     }
   return(true);
  }

bool SubmitJob(const int rates_total)
  {
   if(!g_engine_ready)
     {
      if(InpVerboseLog)
         Print("[PhaseViz Solo] Engine não inicializada - SubmitJob abortado");
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
         PrintFormat("[PhaseViz Solo] SubmitJob falhou (code=%d): %s", err_code, err);
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


void EnsureFetchBuffers()
  {
   const int frame_total = InpFFTWindow;
   const bool use_manual_cycles = InpUseManualCycles && ArraySize(g_cyclePeriods) > 0;
   const int max_cycles = (use_manual_cycles ? (int)MathMin((double)ArraySize(g_cyclePeriods), 24.0)
                                            : (int)MathMax(MathMin((double)InpMaxCandidates, 24.0), 0.0));
   const int safe_frame_total = (frame_total > 0 ? frame_total : 1);
   const int safe_cycles      = (max_cycles > 0 ? max_cycles : 0);
   const int safe_cycle_total = (safe_cycles > 0 ? safe_cycles * safe_frame_total : 1);
   const int safe_cycle_count = (max_cycles > 0 ? max_cycles : 1);
   const int hop = (InpHop > 0 ? InpHop : 1);
   const int estimated_frames = MathMax(1, (safe_frame_total + hop - 1) / hop);
   const int frame_required   = safe_frame_total * estimated_frames;
   const int cycle_required   = safe_cycle_total * estimated_frames;
   const int cycle_list_required = safe_cycle_count * estimated_frames;

   bool ok = true;
   ok = ok && EnsureCapacity(g_waveOut,     frame_required,   "wave_out");
   ok = ok && EnsureCapacity(g_previewOut,  frame_required,   "preview_out");
   ok = ok && EnsureCapacity(g_cyclesOut,   cycle_required,   "cycles_out");
   ok = ok && EnsureCapacity(g_noiseOut,    frame_required,   "noise_out");

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
   ok = ok && EnsureCapacity(g_directionOut,      frame_required, "direction_out");
   ok = ok && EnsureCapacity(g_turnOut,           frame_required, "turn_out");
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
      Print("[PhaseViz Solo] Aviso: redimensionamento de buffers falhou");

   ArrayResize(g_bufPhase,         safe_frame_total);
   ArrayResize(g_bufPhaseSaw,      safe_frame_total);
   ArrayResize(g_bufAmplitudeLine, safe_frame_total);
   ArrayResize(g_bufKalmanLine,    safe_frame_total);
   ArrayResize(g_bufCountdownLine, safe_frame_total);
   ArrayResize(g_bufTurnPulse,     safe_frame_total);
   ArrayResize(g_bufFrequencyLine, safe_frame_total);
   ArrayResize(g_bufVelocityLine,  safe_frame_total);
  }

void CopyResultsToBuffers(const GpuEngineResultInfo &info)
  {
   const int frame_length = info.frame_length;
   const int frame_count  = info.frame_count;
   if(frame_length <= 0 || frame_count <= 0)
      return;

   ClearOutputBuffers();

   const int capacity_phase = ArraySize(g_phaseOut);
   const int max_frames_supported = (frame_length > 0 ? capacity_phase / frame_length : 0);
   int latest_offset = 0;
   if(max_frames_supported <= 0)
     {
      if(InpVerboseLog)
         Print("[PhaseViz Solo] Nenhuma capacidade para phase_out");
      return;
     }

   if(frame_count > max_frames_supported)
     {
      if(InpVerboseLog)
         PrintFormat("[PhaseViz Solo] frame_count=%d truncado para %d", frame_count, max_frames_supported);
      latest_offset = (max_frames_supported - 1) * frame_length;
     }
   else
     {
      latest_offset = (frame_count - 1) * frame_length;
     }

   if(latest_offset + frame_length > capacity_phase)
     {
      if(InpVerboseLog)
         PrintFormat("[PhaseViz Solo] Capacidade insuficiente: offset=%d len=%d cap=%d", latest_offset, frame_length, capacity_phase);
      return;
     }

   for(int i=0; i<frame_length; ++i)
     {
      const int src = latest_offset + (frame_length - 1 - i);

      if(g_buttonState[PhaseButton_Phase] && src < ArraySize(g_phaseOut))
         g_bufPhase[i] = g_phaseOut[src];

      if(g_buttonState[PhaseButton_PhaseSaw] && src < ArraySize(g_phaseOut))
        {
         double phase_deg = g_phaseOut[src];
         double norm = MathMod(phase_deg, 360.0) / 360.0;
         if(norm < 0.0)
            norm += 1.0;
         g_bufPhaseSaw[i] = norm;
        }

      if(g_buttonState[PhaseButton_Amplitude] && src < ArraySize(g_amplitudeOut))
         g_bufAmplitudeLine[i] = g_amplitudeOut[src];

      if(g_buttonState[PhaseButton_Kalman] && src < ArraySize(g_kalmanOut))
         g_bufKalmanLine[i] = g_kalmanOut[src];

      if(g_buttonState[PhaseButton_Countdown] && src < ArraySize(g_countdownOut))
         g_bufCountdownLine[i] = g_countdownOut[src];

      if(g_buttonState[PhaseButton_Turn] && src < ArraySize(g_turnOut))
         g_bufTurnPulse[i] = g_turnOut[src];

      if(g_buttonState[PhaseButton_Frequency] && src < ArraySize(g_frequencyOut))
         g_bufFrequencyLine[i] = g_frequencyOut[src];

      if(g_buttonState[PhaseButton_Velocity] && src < ArraySize(g_velocityOut))
         g_bufVelocityLine[i] = g_velocityOut[src];
     }

   if(InpVerboseLog)
     {
      const int sample_index = latest_offset + (frame_length - 1);
      double phase_sample = (sample_index >= 0 && sample_index < ArraySize(g_phaseOut)) ? g_phaseOut[sample_index] : EMPTY_VALUE;
      double wave_sample = (sample_index >= 0 && sample_index < ArraySize(g_waveOut)) ? g_waveOut[sample_index] : EMPTY_VALUE;
      PrintFormat("[PhaseViz Solo] Sample phase=%.6f wave=%.6f frames=%d len=%d cap=%d",
                  phase_sample,
                  wave_sample,
                  frame_count,
                  frame_length,
                  ArraySize(g_phaseOut));
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

   EnsureFetchBuffers();

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
         PrintFormat("[PhaseViz Solo] FetchResult falhou (code=%d): %s", err_code, err);
      g_job.active = false;
      return false;
     }

   CopyResultsToBuffers(g_lastInfo);
   GPULog::LogFetch(g_job.handle, g_lastInfo);

   const double countdown_latest = (ArraySize(g_countdownOut) > 0 ? g_countdownOut[ArraySize(g_countdownOut)-1] : 0.0);
   g_statusText = StringFormat("Cycle=%d | Period=%.1f | PLV=%.3f | Countdown=%.1f | Velocity=%.3f",
                               g_lastInfo.dominant_cycle,
                               g_lastInfo.dominant_period,
                               g_lastInfo.dominant_plv,
                               countdown_latest,
                               ArraySize(g_velocityOut) > 0 ? g_velocityOut[ArraySize(g_velocityOut)-1] : 0.0);

   g_lastOverlayTag = 0;
   g_lastMarkerTag  = 0;

   g_job.active = false;
   return true;
  }


//--- overlay -------------------------------------------------------
void ClearDentMarkers()
  {
   const long chart_id = ChartID();
   const int total = ObjectsTotal(chart_id, 0, -1);
   for(int i=total-1; i>=0; --i)
     {
      const string name = ObjectName(chart_id, i);
      if(StringFind(name, PHASE_MARKER_PREFIX, 0) == 0)
         ObjectDelete(chart_id, name);
     }
  }

void RefreshPriceOverlay(const datetime &time[], const double &close[], const int rates_total)
  {
   const long chart_id = ChartID();

#ifdef GPU_PHASE_POLYLINE_SUPPORT
   if(!g_buttonState[PhaseButton_PriceLine])
     {
      ObjectDelete(chart_id, PHASE_PRICE_OBJECT);
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
   const int max_points = MathMin(available_bars, PHASE_MAX_OVERLAY_POINTS);
   if(max_points < 2)
      return;

   if(ObjectFind(chart_id, PHASE_PRICE_OBJECT) < 0)
     {
      if(!ObjectCreate(chart_id, PHASE_PRICE_OBJECT, OBJ_POLYLINE, 0, 0, 0))
         return;
      ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_WIDTH, 2);
      ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_HIDDEN, true);
     }

   ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_POINTS, max_points);

   const int start_src = latest_offset + (frame_length - max_points);
   for(int i=0; i<max_points; ++i)
     {
      const int src = start_src + i;
      const int series_index = max_points - 1 - i;
      datetime t = time[series_index];
      double price = (src >= 0 && src < ArraySize(g_reconOut)) ? g_reconOut[src] : close[series_index];
      ObjectSetInteger(chart_id, PHASE_PRICE_OBJECT, OBJPROP_TIME,  i, t);
      ObjectSetDouble (chart_id, PHASE_PRICE_OBJECT, OBJPROP_PRICE, i, price);
     }

   g_lastOverlayTag = g_lastInfo.user_tag;
#else
   ObjectDelete(chart_id, PHASE_PRICE_OBJECT);
#endif
  }

void RefreshDentMarkers(const datetime &time[], const double &close[], const int rates_total)
  {
   const long chart_id = ChartID();

#ifdef GPU_PHASE_MARKER_SUPPORT
   if(!g_buttonState[PhaseButton_Markers])
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
   const int max_points = MathMin(available_bars, PHASE_MAX_OVERLAY_POINTS);
   if(max_points < 2)
      return;

   int markers = 0;
   const int start_src = latest_offset + (frame_length - max_points);
   for(int i=0; i<max_points && markers < PHASE_MAX_MARKERS; ++i)
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
      const string name = PHASE_MARKER_PREFIX + IntegerToString(markers);

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
   if(!g_buttonState[PhaseButton_Hud])
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

//--- MQL5 event handlers ------------------------------------------
int OnInit()
  {
   const bool tester_mode = (MQLInfoInteger(MQL_TESTER) != 0);
   bool use_service = true;
   if(!tester_mode && !InpUseGpuService)
      Print("[PhaseViz Solo] UseGpuService ignorado (serviço obrigatório nesta build).");

   SetIndexBuffer(0, g_bufPhase,         INDICATOR_DATA);
   SetIndexBuffer(1, g_bufPhaseSaw,      INDICATOR_DATA);
   SetIndexBuffer(2, g_bufAmplitudeLine, INDICATOR_DATA);
   SetIndexBuffer(3, g_bufKalmanLine,    INDICATOR_DATA);
   SetIndexBuffer(4, g_bufCountdownLine, INDICATOR_DATA);
   SetIndexBuffer(5, g_bufTurnPulse,     INDICATOR_DATA);
   SetIndexBuffer(6, g_bufFrequencyLine, INDICATOR_DATA);
   SetIndexBuffer(7, g_bufVelocityLine,  INDICATOR_DATA);

   ArraySetAsSeries(g_bufPhase,         true);
   ArraySetAsSeries(g_bufPhaseSaw,      true);
   ArraySetAsSeries(g_bufAmplitudeLine, true);
   ArraySetAsSeries(g_bufKalmanLine,    true);
   ArraySetAsSeries(g_bufCountdownLine, true);
   ArraySetAsSeries(g_bufTurnPulse,     true);
   ArraySetAsSeries(g_bufFrequencyLine, true);
   ArraySetAsSeries(g_bufVelocityLine,  true);

   ClearOutputBuffers();

   g_buttonState[PhaseButton_Phase]      = true;
   g_buttonState[PhaseButton_PhaseSaw]   = true;
   g_buttonState[PhaseButton_Amplitude]  = true;
   g_buttonState[PhaseButton_Kalman]     = true;
   g_buttonState[PhaseButton_Countdown]  = true;
   g_buttonState[PhaseButton_Turn]       = true;
   g_buttonState[PhaseButton_Frequency]  = false;
   g_buttonState[PhaseButton_Velocity]   = false;
   g_buttonState[PhaseButton_PriceLine]  = true;
   g_buttonState[PhaseButton_Markers]    = true;
   g_buttonState[PhaseButton_Hud]        = true;

   CreateButtons();
   UpdateButtons();
   ApplyVisibility();

   g_prevLogging = GpuLogsEnabled();
   GpuSetLogging(InpVerboseLog);
   GPULog::Init("PhaseVizSolo", true, InpVerboseLog);
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
      PrintFormat("[PhaseViz Solo] Falha ao inicializar a GPU Engine (code=%d): %s", err_code, err);
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
   g_backendSummary = "Backend: " + backend_desc;
   GPULog::LogOpen(InpGPUDevice,
                   InpFFTWindow,
                   InpHop,
                   1,
                   use_service,
                   tester_mode,
                   backend_name);
   Print("[PhaseViz Solo] " + g_backendSummary);

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

   if(idx == PhaseButton_PriceLine)
      g_lastOverlayTag = 0;
   if(idx == PhaseButton_Markers)
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
//--- zigzag helpers
int    g_zigzagHandle   = INVALID_HANDLE;
double g_zigzagRaw[];
double g_zigzagSeries[];
int    g_pivotIndex[];
double g_pivotValue[];
double g_zigzagChron[];

//--- feed helpers
double g_priceSeries[];
double g_measureSeries[];
double g_maTemp1[];
double g_maTemp2[];
