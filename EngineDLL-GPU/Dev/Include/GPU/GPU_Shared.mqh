//+------------------------------------------------------------------+
//| GPU_Shared                                                      |
//| Shared buffers publicados pelo hub para indicadores e agents.   |
//+------------------------------------------------------------------+
#ifndef __WAVESPEC_SHARED_MQH__
#define __WAVESPEC_SHARED_MQH__

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

namespace GPUShared
  {
   datetime last_update   = 0;
   int      frame_count   = 0;
   int      frame_length  = 0;
   int      cycle_count   = 0;

   double wave[];
   double preview[];
   double noise[];
   double cycles[];
   double measurement[];
   double cycle_periods[];

   double phase[];
   double phase_unwrapped[];
   double amplitude[];
   double period[];
   double frequency[];
   double eta[];
   double countdown[];
   double recon[];
   double kalman[];
   double turn[];
   double confidence[];
   double amp_delta[];
   double direction[];
   double power[];
   double velocity[];

   double phase_all[];
   double phase_unwrapped_all[];
   double amplitude_all[];
   double period_all[];
   double frequency_all[];
   double eta_all[];
   double countdown_all[];
   double direction_all[];
   double recon_all[];
   double kalman_all[];
   double turn_all[];
   double confidence_all[];
   double amp_delta_all[];
   double power_all[];
   double velocity_all[];

   double plv_cycles[];
   double snr_cycles[];

   double dominant_snr = 0.0;
   double dominant_plv = 0.0;
   int     dominant_cycle = -1;

   GpuEngineResultInfo last_info;

   void EnsureSize(const int total,
                   const int cycles_total,
                   const int cycles_count)
     {
      ArrayResize(wave,    total);
      ArrayResize(preview, total);
      ArrayResize(noise,   total);
      ArrayResize(cycles,  cycles_total);
      ArrayResize(measurement, total);
      ArrayResize(cycle_periods, cycles_count);

      ArrayResize(phase,            total);
      ArrayResize(phase_unwrapped,  total);
      ArrayResize(amplitude,        total);
      ArrayResize(period,           total);
      ArrayResize(frequency,        total);
      ArrayResize(eta,              total);
      ArrayResize(countdown,        total);
      ArrayResize(recon,            total);
      ArrayResize(kalman,           total);
      ArrayResize(turn,             total);
      ArrayResize(confidence,       total);
      ArrayResize(amp_delta,        total);
      ArrayResize(direction,        total);
      ArrayResize(power,            total);
      ArrayResize(velocity,         total);

      ArrayResize(phase_all,            cycles_total);
      ArrayResize(phase_unwrapped_all,  cycles_total);
      ArrayResize(amplitude_all,        cycles_total);
      ArrayResize(period_all,           cycles_total);
      ArrayResize(frequency_all,        cycles_total);
      ArrayResize(eta_all,              cycles_total);
      ArrayResize(countdown_all,        cycles_total);
      ArrayResize(direction_all,        cycles_total);
      ArrayResize(recon_all,            cycles_total);
      ArrayResize(kalman_all,           cycles_total);
      ArrayResize(turn_all,             cycles_total);
      ArrayResize(confidence_all,       cycles_total);
      ArrayResize(amp_delta_all,        cycles_total);
      ArrayResize(power_all,            cycles_total);
      ArrayResize(velocity_all,         cycles_total);

      ArrayResize(plv_cycles, cycles_count);
      ArrayResize(snr_cycles, cycles_count);
     }

   void Publish(const double &wave_src[],
                const double &preview_src[],
                const double &noise_src[],
                const double &cycles_src[],
                const double &measurement_src[],
                const double &cycle_periods_src[],
                const double &phase_src[],
                const double &phase_unwrapped_src[],
                const double &amplitude_src[],
                const double &period_src[],
                const double &frequency_src[],
                const double &eta_src[],
                const double &countdown_src[],
                const double &recon_src[],
                const double &kalman_src[],
                const double &turn_src[],
                const double &confidence_src[],
                const double &amp_delta_src[],
                const double &direction_src[],
                const double &power_src[],
                const double &velocity_src[],
                const double &phase_all_src[],
                const double &phase_unwrapped_all_src[],
                const double &amplitude_all_src[],
                const double &period_all_src[],
                const double &frequency_all_src[],
                const double &eta_all_src[],
                const double &countdown_all_src[],
                const double &direction_all_src[],
                const double &recon_all_src[],
                const double &kalman_all_src[],
                const double &turn_all_src[],
                const double &confidence_all_src[],
                const double &amp_delta_all_src[],
                const double &power_all_src[],
                const double &velocity_all_src[],
                const double &plv_cycles_src[],
                const double &snr_cycles_src[],
                const GpuEngineResultInfo &info)
     {
      frame_count  = info.frame_count;
      frame_length = info.frame_length;
      cycle_count  = info.cycle_count;

      const int total = frame_count * frame_length;
      const int cycles_total = total * MathMax(cycle_count, 0);

      EnsureSize(total, cycles_total, cycle_count);

      ArrayCopy(wave,    wave_src,    0, 0, total);
      ArrayCopy(preview, preview_src, 0, 0, total);
      ArrayCopy(noise,   noise_src,   0, 0, total);
      ArrayCopy(measurement, measurement_src, 0, 0, total);

      if(cycles_total > 0)
         ArrayCopy(cycles, cycles_src, 0, 0, cycles_total);
      else
         ArrayResize(cycles, 0);

      if(cycle_count > 0 && ArraySize(cycle_periods_src) >= cycle_count)
         ArrayCopy(cycle_periods, cycle_periods_src, 0, 0, cycle_count);
      else
        {
         ArrayResize(cycle_periods, cycle_count);
         ArrayInitialize(cycle_periods, 0.0);
        }

      ArrayCopy(phase,           phase_src,           0, 0, total);
      ArrayCopy(phase_unwrapped, phase_unwrapped_src,0, 0, total);
      ArrayCopy(amplitude,       amplitude_src,       0, 0, total);
      ArrayCopy(period,          period_src,          0, 0, total);
      ArrayCopy(frequency,       frequency_src,       0, 0, total);
      ArrayCopy(eta,             eta_src,             0, 0, total);
      ArrayCopy(countdown,       countdown_src,       0, 0, total);
      ArrayCopy(recon,           recon_src,           0, 0, total);
      ArrayCopy(kalman,          kalman_src,          0, 0, total);
      ArrayCopy(turn,            turn_src,            0, 0, total);
      ArrayCopy(confidence,      confidence_src,      0, 0, total);
      ArrayCopy(amp_delta,       amp_delta_src,       0, 0, total);
      ArrayCopy(direction,       direction_src,       0, 0, total);
      ArrayCopy(power,           power_src,           0, 0, total);
      ArrayCopy(velocity,        velocity_src,        0, 0, total);

      ArrayCopy(phase_all,            phase_all_src,            0, 0, cycles_total);
      ArrayCopy(phase_unwrapped_all,  phase_unwrapped_all_src,  0, 0, cycles_total);
      ArrayCopy(amplitude_all,        amplitude_all_src,        0, 0, cycles_total);
      ArrayCopy(period_all,           period_all_src,           0, 0, cycles_total);
      ArrayCopy(frequency_all,        frequency_all_src,        0, 0, cycles_total);
      ArrayCopy(eta_all,              eta_all_src,              0, 0, cycles_total);
      ArrayCopy(countdown_all,        countdown_all_src,        0, 0, cycles_total);
      ArrayCopy(direction_all,        direction_all_src,        0, 0, cycles_total);
      ArrayCopy(recon_all,            recon_all_src,            0, 0, cycles_total);
      ArrayCopy(kalman_all,           kalman_all_src,           0, 0, cycles_total);
      ArrayCopy(turn_all,             turn_all_src,             0, 0, cycles_total);
      ArrayCopy(confidence_all,       confidence_all_src,       0, 0, cycles_total);
      ArrayCopy(amp_delta_all,        amp_delta_all_src,        0, 0, cycles_total);
      ArrayCopy(power_all,            power_all_src,            0, 0, cycles_total);
      ArrayCopy(velocity_all,         velocity_all_src,         0, 0, cycles_total);

      ArrayCopy(plv_cycles, plv_cycles_src, 0, 0, cycle_count);
      ArrayCopy(snr_cycles, snr_cycles_src, 0, 0, cycle_count);

      last_info = info;
      dominant_snr = info.dominant_snr;
      dominant_plv = info.dominant_plv;
      dominant_cycle = info.dominant_cycle;
      last_update = TimeCurrent();
     }
  }

#endif

//+------------------------------------------------------------------+
//| End of file                                                      |
//+------------------------------------------------------------------+
