#ifndef __WAVESPEC_GPU_LOG_MQH__
#define __WAVESPEC_GPU_LOG_MQH__

#import "kernel32.dll"
int  CreateDirectoryW(ushort &path[], int lpSecurityAttributes);
int  GetLastError();
#import

namespace GPULog
  {
   bool   g_ready      = false;
   bool   g_enabled    = true;
   bool   g_debug      = false;
   string g_identity   = "";
   string g_file_rel   = "WaveSpecGPU\\logs\\gpu_interactions.log";
   ulong  g_sequence   = 0;

   const int ERROR_ALREADY_EXISTS = 183;

   string UlongToString(const ulong value)
     {
      return LongToString((long)value);
     }

   string DoubleToStringFixed(const double value,
                              const int    digits = 6)
     {
      return DoubleToString(value, digits);
     }

   void ReplaceAll(string &text,
                   const string what,
                   const string with)
     {
      while(StringFind(text, what, 0) >= 0)
         text = StringReplace(text, what, with);
     }

   string Sanitize(const string text)
     {
      string tmp = text;
      ReplaceAll(tmp, "\r", " ");
      ReplaceAll(tmp, "\n", " ");
      ReplaceAll(tmp, "\t", " ");
      return tmp;
     }

   bool CreateDirectoryDeep(const string absolute_path)
     {
      ushort wide[];
      StringToShortArray(absolute_path + "\0", wide);
      if(CreateDirectoryW(wide, 0) != 0)
         return true;
      const int err = GetLastError();
      return (err == ERROR_ALREADY_EXISTS);
     }

   string BuildAbsolutePath()
     {
      string root = TerminalInfoString(TERMINAL_DATA_PATH);
      if(StringLen(root) == 0)
         return "";
      return root + "\\MQL5\\Files";
     }

   bool EnsureDestination()
     {
      if(g_ready)
         return true;

      const string files_root = BuildAbsolutePath();
      if(StringLen(files_root) == 0)
         return false;

      if(!CreateDirectoryDeep(files_root))
         return false;
      if(!CreateDirectoryDeep(files_root + "\\WaveSpecGPU"))
         return false;
      if(!CreateDirectoryDeep(files_root + "\\WaveSpecGPU\\logs"))
         return false;

      g_ready = true;
      return true;
     }

   string Timestamp()
     {
      datetime now = TimeLocal();
      return TimeToString(now, TIME_DATE | TIME_SECONDS);
     }

   void WriteRaw(const string level,
                 const string event_name,
                 const string payload)
     {
      if(!g_enabled)
         return;
      if(StringLen(g_identity) == 0)
         return;
      if(!EnsureDestination())
         return;

      const string line = StringFormat("%s\t%s\t%s\t%s\t%s",
                                       Timestamp(),
                                       g_identity,
                                       level,
                                       event_name,
                                       Sanitize(payload));

      const int handle = FileOpen(g_file_rel,
                                  FILE_WRITE | FILE_TXT | FILE_READ | FILE_SHARE_READ | FILE_SHARE_WRITE);
      if(handle == INVALID_HANDLE)
         return;

      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, line);
      FileClose(handle);
     }

   void Init(const string identity,
             const bool   enable = true,
             const bool   debug  = false)
     {
      g_identity = identity;
      g_enabled  = enable;
      g_debug    = debug;
      EnsureDestination();
      if(enable)
         WriteRaw("INFO", "init", "identity=" + Sanitize(identity));
     }

   void SetEnabled(const bool enable)
     {
      g_enabled = enable;
     }

   void SetDebug(const bool enable)
     {
      g_debug = enable;
     }

   void Info(const string event_name,
             const string payload)
     {
      WriteRaw("INFO", event_name, payload);
     }

   void Debug(const string event_name,
              const string payload)
     {
      if(!g_debug)
         return;
      WriteRaw("DEBUG", event_name, payload);
     }

   void Error(const string event_name,
              const string payload)
     {
      WriteRaw("ERROR", event_name, payload);
     }

   void LogOpen(const int device_id,
                const int window,
                const int hop,
                const int batch,
                const bool prefer_service,
                const bool tester_mode,
                const string backend)
     {
      const string msg = StringFormat("device=%d window=%d hop=%d batch=%d prefer_service=%s tester_mode=%s backend=%s",
                                      device_id,
                                      window,
                                      hop,
                                      batch,
                                      prefer_service ? "true" : "false",
                                      tester_mode ? "true" : "false",
                                      Sanitize(backend));
      Info("open", msg);
     }

   void LogClose()
     {
      Info("close", "");
     }

   void LogSubmit(const ulong handle,
                  const ulong tag,
                  const uint  flags,
                  const int   frame_count,
                  const int   frame_length,
                  const int   cycle_count,
                  const int   measurement_count,
                  const int   bars_reference)
     {
      const string msg = StringFormat("handle=%I64u tag=%I64u flags=%u frame_count=%d frame_length=%d cycles=%d measurement=%d bars=%d",
                                      handle,
                                      tag,
                                      flags,
                                      frame_count,
                                      frame_length,
                                      cycle_count,
                                      measurement_count,
                                      bars_reference);
      Info("submit", msg);
     }

   void LogPoll(const ulong handle,
                const int   status)
     {
      Debug("poll", StringFormat("handle=%I64u status=%d", handle, status));
     }

   void LogFetch(const ulong handle,
                 const GpuEngineResultInfo &info)
     {
      const string msg = StringFormat("handle=%I64u status=%d frame_count=%d frame_length=%d cycles=%d dominant_cycle=%d dominant_period=%s dominant_plv=%s dominant_confidence=%s elapsed_ms=%s",
                                      handle,
                                      info.status,
                                      info.frame_count,
                                      info.frame_length,
                                      info.cycle_count,
                                      info.dominant_cycle,
                                      DoubleToStringFixed(info.dominant_period, 4),
                                      DoubleToStringFixed(info.dominant_plv, 4),
                                      DoubleToStringFixed(info.dominant_confidence, 4),
                                      DoubleToStringFixed(info.elapsed_ms, 2));
      Info("fetch", msg);
     }

   void LogError(const string stage,
                 const int    status,
                 const string message)
     {
      const string msg = StringFormat("status=%d msg=%s", status, Sanitize(message));
      Error(stage, msg);
     }

   void LogErrorText(const string stage,
                     const string message)
     {
      Error(stage, Sanitize(message));
     }
  } // namespace GPULog

#endif // __WAVESPEC_GPU_LOG_MQH__
