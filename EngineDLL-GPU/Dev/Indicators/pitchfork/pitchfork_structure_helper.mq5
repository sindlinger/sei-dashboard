//+------------------------------------------------------------------+
//|                                      pitchfork_structure_helper.mq5 |
//|   Market structure helper based on ZigZag pivot sequences           |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   9

#property indicator_type1   DRAW_NONE
#property indicator_type2   DRAW_NONE
#property indicator_type3   DRAW_NONE
#property indicator_type4   DRAW_NONE
#property indicator_type5   DRAW_NONE
#property indicator_type6   DRAW_NONE
#property indicator_type7   DRAW_NONE
#property indicator_type8   DRAW_NONE
#property indicator_type9   DRAW_NONE

#property indicator_label1  "Trend Depth1"
#property indicator_label2  "Last High Depth1"
#property indicator_label3  "Last Low Depth1"
#property indicator_label4  "Trend Depth2"
#property indicator_label5  "Last High Depth2"
#property indicator_label6  "Last Low Depth2"
#property indicator_label7  "Trend Depth3"
#property indicator_label8  "Last High Depth3"
#property indicator_label9  "Last Low Depth3"

input group "ZigZag Settings"
input int  InpDeviation = 8;
input int  InpBackstep  = 3;

input group "Depth Configuration"
input bool InpUseDepth1 = true;
input int  InpDepth1    = 24;
input bool InpUseDepth2 = true;
input int  InpDepth2    = 55;
input bool InpUseDepth3 = false;
input int  InpDepth3    = 89;

input group "Processing"
input int  InpMaxScanBars = 2000;

input group "Panel"
input bool   InpShowPanel      = true;
input ENUM_BASE_CORNER InpPanelCorner  = CORNER_RIGHT_UPPER;
input int    InpPanelXOffset   = 20;
input int    InpPanelYOffset   = 40;
input color  InpPanelBgColor   = clrBlack;
input int    InpPanelBgOpacity = 40;
input color  InpBullColor      = clrLimeGreen;
input color  InpBearColor      = clrTomato;
input color  InpNeutralColor   = clrSilver;

const string PANEL_NAME = "PF_STRUCT_PANEL";

struct SDepthState
{
   bool   enabled;
   int    depth;
   int    handle;
   double trend_buffer[];
   double last_high_buffer[];
   double last_low_buffer[];

   SDepthState(): enabled(false), depth(0), handle(INVALID_HANDLE) {}
};

#define      MAX_DEPTHS 3
const double TREND_TOLERANCE_POINTS = 2.0; // multiplier over _Point when comparing swings

SDepthState g_states[MAX_DEPTHS];
int         g_last_trend[MAX_DEPTHS];
double      g_last_high[MAX_DEPTHS];
double      g_last_low[MAX_DEPTHS];

void ConfigurePlotBuffers();
void ReleaseHandles();
void UpdateDepthState(const int index,
                      const datetime &time[],
                      const double &high[],
                      const double &low[],
                      const double &close[],
                      int rates_total);
void InitializeDepthState(const int index, bool enabled, int depth);
void ConfigurePivotBuffer(const int plot_index, double &buffer[], const string label);
void RenderPanel();
void ClearPanel();
ENUM_ANCHOR_POINT GetAnchorForCorner(const ENUM_BASE_CORNER corner);

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      g_last_trend[idx] = 0;
      g_last_high[idx]  = 0.0;
      g_last_low[idx]   = 0.0;
   }

   InitializeDepthState(0, InpUseDepth1, InpDepth1);
   InitializeDepthState(1, InpUseDepth2, InpDepth2);
   InitializeDepthState(2, InpUseDepth3, InpDepth3);

   ConfigurePlotBuffers();

   if(InpShowPanel)
      RenderPanel();
   else
      ClearPanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ReleaseHandles();
    ClearPanel();
}

//+------------------------------------------------------------------+
//| Calculation                                                      |
//+------------------------------------------------------------------+
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
   if(rates_total <= 0)
      return(rates_total);

   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      if(!g_states[idx].enabled || g_states[idx].handle == INVALID_HANDLE)
      {
         ArrayResize(g_states[idx].trend_buffer, rates_total);
         ArrayResize(g_states[idx].last_high_buffer, rates_total);
         ArrayResize(g_states[idx].last_low_buffer, rates_total);
         ArraySetAsSeries(g_states[idx].trend_buffer, true);
         ArraySetAsSeries(g_states[idx].last_high_buffer, true);
         ArraySetAsSeries(g_states[idx].last_low_buffer, true);
         ArrayInitialize(g_states[idx].trend_buffer, 0.0);
         ArrayInitialize(g_states[idx].last_high_buffer, EMPTY_VALUE);
         ArrayInitialize(g_states[idx].last_low_buffer, EMPTY_VALUE);
         g_last_trend[idx] = 0;
         g_last_high[idx] = 0.0;
         g_last_low[idx] = 0.0;
         continue;
      }

      UpdateDepthState(idx, time, high, low, close, rates_total);
   }

   if(InpShowPanel)
      RenderPanel();
   else
      ClearPanel();

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Configure indicator buffers                                      |
//+------------------------------------------------------------------+
void ConfigurePlotBuffers()
{
   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      int base = idx * 3;
      string suffix = StringFormat("Depth%d", g_states[idx].depth);
      if(!g_states[idx].enabled)
         suffix = StringFormat("Depth%d(disabled)", g_states[idx].depth);

      ArrayResize(g_states[idx].trend_buffer, 0);
      ArrayResize(g_states[idx].last_high_buffer, 0);
      ArrayResize(g_states[idx].last_low_buffer, 0);

      ConfigurePivotBuffer(base + 0, g_states[idx].trend_buffer,  StringFormat("Trend %s", suffix));
      ConfigurePivotBuffer(base + 1, g_states[idx].last_high_buffer, StringFormat("Last High %s", suffix));
      ConfigurePivotBuffer(base + 2, g_states[idx].last_low_buffer,  StringFormat("Last Low %s", suffix));
   }
}

//+------------------------------------------------------------------+
//| Create or disable a depth state                                  |
//+------------------------------------------------------------------+
void InitializeDepthState(const int index, bool enabled, int depth)
{
   if(index < 0 || index >= MAX_DEPTHS)
      return;

   g_states[index].enabled = enabled;
   g_states[index].depth = depth;
   g_states[index].handle = INVALID_HANDLE;

   if(!enabled || depth <= 0)
      return;

   g_states[index].handle = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\ZigZag",
                                    depth, InpDeviation, InpBackstep);
   if(g_states[index].handle == INVALID_HANDLE)
   {
      g_states[index].handle = iCustom(_Symbol, PERIOD_CURRENT, "ZigZag",
                                       depth, InpDeviation, InpBackstep);
   }

   if(g_states[index].handle == INVALID_HANDLE)
   {
      PrintFormat("[StructureHelper] Falha ao criar ZigZag depth=%d (err=%d)", depth, GetLastError());
      g_states[index].enabled = false;
   }
}

//+------------------------------------------------------------------+
//| Release ZigZag handles                                           |
//+------------------------------------------------------------------+
void ReleaseHandles()
{
   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      if(g_states[idx].handle != INVALID_HANDLE)
      {
         IndicatorRelease(g_states[idx].handle);
         g_states[idx].handle = INVALID_HANDLE;
      }
      g_last_trend[idx] = 0;
      g_last_high[idx] = 0.0;
      g_last_low[idx] = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Update a depth state                                             |
//+------------------------------------------------------------------+
void UpdateDepthState(const int index,
                      const datetime &time[],
                      const double &high[],
                      const double &low[],
                      const double &close[],
                      int rates_total)
{
   if(index < 0 || index >= MAX_DEPTHS)
      return;

   int requested = (InpMaxScanBars > 0) ? MathMin(InpMaxScanBars, rates_total) : rates_total;
   if(requested <= 0)
      requested = rates_total;

   ArrayResize(g_states[index].trend_buffer, rates_total);
   ArrayResize(g_states[index].last_high_buffer, rates_total);
   ArrayResize(g_states[index].last_low_buffer, rates_total);
   ArraySetAsSeries(g_states[index].trend_buffer, true);
   ArraySetAsSeries(g_states[index].last_high_buffer, true);
   ArraySetAsSeries(g_states[index].last_low_buffer, true);

   ArrayInitialize(g_states[index].trend_buffer, 0.0);
   ArrayInitialize(g_states[index].last_high_buffer, EMPTY_VALUE);
   ArrayInitialize(g_states[index].last_low_buffer, EMPTY_VALUE);

   if(g_states[index].handle == INVALID_HANDLE)
      return;

   double zigzag_buffer[];
   ArraySetAsSeries(zigzag_buffer, true);
   int copied = CopyBuffer(g_states[index].handle, 0, 0, requested, zigzag_buffer);
   if(copied <= 0)
      return;

   double last_high_price = 0.0;
   double prev_high_price = 0.0;
   int    last_high_index = -1;
   int    prev_high_index = -1;

   double last_low_price = 0.0;
   double prev_low_price = 0.0;
   int    last_low_index = -1;
   int    prev_low_index = -1;

   double tol = _Point * TREND_TOLERANCE_POINTS;

   for(int i = 0; i < copied; ++i)
   {
      double price = zigzag_buffer[i];
      if(price == 0.0)
         continue;

      bool is_high = false;
      double diff_high = MathAbs(price - high[i]);
      double diff_low = MathAbs(price - low[i]);
      if(diff_high < diff_low - tol)
         is_high = true;
      else if(diff_low < diff_high - tol)
         is_high = false;
      else
         is_high = (price >= close[i]);

      if(is_high)
      {
         if(last_high_index < 0)
         {
            last_high_index = i;
            last_high_price = price;
         }
         else if(prev_high_index < 0)
         {
            prev_high_index = i;
            prev_high_price = price;
         }
      }
      else
      {
         if(last_low_index < 0)
         {
            last_low_index = i;
            last_low_price = price;
         }
         else if(prev_low_index < 0)
         {
            prev_low_index = i;
            prev_low_price = price;
         }
      }

      if(last_high_index >= 0 && prev_high_index >= 0 &&
         last_low_index >= 0 && prev_low_index >= 0)
         break;
   }

   int trend = 0;
   if(last_high_index >= 0 && prev_high_index >= 0 &&
      last_low_index >= 0 && prev_low_index >= 0)
   {
      bool higher_high = (last_high_price > prev_high_price + tol);
      bool higher_low  = (last_low_price  > prev_low_price  + tol);
      bool lower_high  = (last_high_price < prev_high_price - tol);
      bool lower_low   = (last_low_price  < prev_low_price  - tol);

      if(higher_high && higher_low)
         trend = 1;
      else if(lower_high && lower_low)
         trend = -1;
      else
         trend = 0;
   }

   ArrayInitialize(g_states[index].trend_buffer, trend);

   if(last_high_index >= 0 && last_high_index < rates_total)
   {
      g_states[index].last_high_buffer[last_high_index] = last_high_price;
      g_states[index].last_high_buffer[0] = last_high_price;
   }

   if(last_low_index >= 0 && last_low_index < rates_total)
   {
      g_states[index].last_low_buffer[last_low_index] = last_low_price;
      g_states[index].last_low_buffer[0] = last_low_price;
   }

   g_last_trend[index] = trend;
   g_last_high[index]  = last_high_price;
   g_last_low[index]   = last_low_price;
}

void ConfigurePivotBuffer(const int plot_index, double &buffer[], const string label)
{
   SetIndexBuffer(plot_index, buffer, INDICATOR_DATA);
   ArraySetAsSeries(buffer, true);
   PlotIndexSetInteger(plot_index, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(plot_index, PLOT_LABEL, label);
   PlotIndexSetDouble(plot_index, PLOT_EMPTY_VALUE, EMPTY_VALUE);
}

ENUM_ANCHOR_POINT GetAnchorForCorner(const ENUM_BASE_CORNER corner)
{
   switch(corner)
   {
      case CORNER_LEFT_LOWER:   return ANCHOR_LEFT_LOWER;
      case CORNER_RIGHT_UPPER:  return ANCHOR_RIGHT_UPPER;
      case CORNER_RIGHT_LOWER:  return ANCHOR_RIGHT_LOWER;
      case CORNER_LEFT_UPPER:
      default:                  return ANCHOR_LEFT_UPPER;
   }
}

void RenderPanel()
{
   if(!InpShowPanel)
   {
      ClearPanel();
      return;
   }

   int active = 0;
   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      if(g_states[idx].enabled)
         active++;
   }

   if(active == 0)
   {
      ClearPanel();
      return;
   }

   int panel_width = 260;
   int line_height = 16;
   int padding = 6;
   int panel_height = padding * 2 + line_height * active;

   if(ObjectFind(0, PANEL_NAME) < 0)
   {
      ObjectCreate(0, PANEL_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_HIDDEN, false);
   }

   int alpha = MathMax(MathMin(InpPanelBgOpacity, 255), 0);
   int r = (InpPanelBgColor >> 16) & 0xFF;
   int g = (InpPanelBgColor >> 8)  & 0xFF;
   int b =  InpPanelBgColor        & 0xFF;
   color panel_color = (color)((alpha << 24) | (r << 16) | (g << 8) | b);

   ENUM_ANCHOR_POINT anchor = GetAnchorForCorner(InpPanelCorner);

   ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER, InpPanelCorner);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_XDISTANCE, InpPanelXOffset);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_YDISTANCE, InpPanelYOffset);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_XSIZE, panel_width);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_YSIZE, panel_height);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BGCOLOR, panel_color);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR, panel_color);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BORDER_TYPE, 1);
   ObjectSetInteger(0, PANEL_NAME, OBJPROP_BACK, true);

   int rendered = 0;
   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      string line_name = StringFormat("%s_LINE_%d", PANEL_NAME, idx);

      if(!g_states[idx].enabled)
      {
         if(ObjectFind(0, line_name) >= 0)
            ObjectDelete(0, line_name);
         continue;
      }

      if(ObjectFind(0, line_name) < 0)
      {
         ObjectCreate(0, line_name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, line_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, line_name, OBJPROP_HIDDEN, false);
         ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
      }

      ObjectSetInteger(0, line_name, OBJPROP_CORNER, InpPanelCorner);
      ObjectSetInteger(0, line_name, OBJPROP_XDISTANCE, InpPanelXOffset + padding);
      ObjectSetInteger(0, line_name, OBJPROP_YDISTANCE, InpPanelYOffset + padding + rendered * line_height);
      ObjectSetInteger(0, line_name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, line_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, line_name, OBJPROP_FONT, "Consolas");

      int trend = g_last_trend[idx];
      string trend_text = "NEUTRAL";
      color trend_color = InpNeutralColor;
      string direction_icon = "→";

      if(trend > 0)
      {
         trend_text = "UP";
         trend_color = InpBullColor;
         direction_icon = "↑";
      }
      else if(trend < 0)
      {
         trend_text = "DOWN";
         trend_color = InpBearColor;
         direction_icon = "↓";
      }

      string high_str = (g_last_high[idx] > 0.0) ? DoubleToString(g_last_high[idx], _Digits) : "--";
      string low_str  = (g_last_low[idx]  > 0.0) ? DoubleToString(g_last_low[idx],  _Digits) : "--";

      string text = StringFormat("Depth %d  %s %s  High:%s  Low:%s",
                                 g_states[idx].depth,
                                 direction_icon,
                                 trend_text,
                                 high_str,
                                 low_str);

      ObjectSetString(0, line_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, line_name, OBJPROP_COLOR, trend_color);

      rendered++;
   }

   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      if(!g_states[idx].enabled)
      {
         string line_name = StringFormat("%s_LINE_%d", PANEL_NAME, idx);
         if(ObjectFind(0, line_name) >= 0)
            ObjectDelete(0, line_name);
      }
   }
}

void ClearPanel()
{
   if(ObjectFind(0, PANEL_NAME) >= 0)
      ObjectDelete(0, PANEL_NAME);

   for(int idx = 0; idx < MAX_DEPTHS; ++idx)
   {
      string line_name = StringFormat("%s_LINE_%d", PANEL_NAME, idx);
      if(ObjectFind(0, line_name) >= 0)
         ObjectDelete(0, line_name);
   }
}
