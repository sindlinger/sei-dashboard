//+------------------------------------------------------------------+
//| GPU_Subwindows.mqh                                              |
// Build ID: GPT5-2025-10-23 rev.1
//| Utilities built on top of fxsaber's SUBWINDOW helper.            |
//+------------------------------------------------------------------+
#ifndef __GPU_SUBWINDOW_CONTROLLER_MQH__
#define __GPU_SUBWINDOW_CONTROLLER_MQH__

class CSubwindowController
  {
public:
   static bool EnsureCount(const long chart_id,
                           const int desired_subwindow)
     {
      return (desired_subwindow >= 0);
     }

   static bool Attach(const long chart_id,
                      const int sub_window,
                      const int indicator_handle)
     {
      if(indicator_handle == INVALID_HANDLE)
         return false;
      if(!EnsureCount(chart_id, sub_window))
         return false;
      return ChartIndicatorAdd(chart_id, sub_window, indicator_handle);
     }

   static bool Detach(const long chart_id,
                      const int sub_window,
                      int &indicator_handle,
                      const string short_name)
     {
      if(indicator_handle == INVALID_HANDLE)
         return false;

      const bool removed = ChartIndicatorDelete(chart_id, sub_window, short_name);
      IndicatorRelease(indicator_handle);
      indicator_handle = INVALID_HANDLE;

      if(removed)
        {
         const int remaining = (int)ChartIndicatorsTotal(chart_id, sub_window);
         if(sub_window > 0 && remaining == 0)
           {
            ChartSetInteger(chart_id, CHART_WINDOW_IS_VISIBLE, sub_window, false);
            ChartRedraw(chart_id);
           }
        }
      return removed;
     }
  };

#endif // __GPU_SUBWINDOW_CONTROLLER_MQH__
