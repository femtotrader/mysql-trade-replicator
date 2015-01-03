//+------------------------------------------------------------------+
//|                                                volume_sizing.mqh |
//|                                    Copyright © 2014, FemtoTrader |
//|                       https://sites.google.com/site/femtotrader/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2014, FemtoTrader"
#property link      "https://sites.google.com/site/femtotrader/"
#property strict


#include <Object.mqh>
#include <string_toolbox.mqh>
#include <display_price_volume.mqh>


enum VolumeSizingMode
  {
   VolumeSizingMode_MS  =  0,    //VolumeSizingMode MS: MaSter
   VolumeSizingMode_FX  =  1,    //VolumeSizingMode FX: FiXed
   VolumeSizingMode_BP  =  2,    //VolumeSizingMode BP: Balance Percent
   VolumeSizingMode_EP  =  3,    //VolumeSizingMode EP: Equity Percent
   VolumeSizingMode_FMP =  4,    //VolumeSizingMode FMP: Free Margin Percent
   VolumeSizingMode_C   =  5,    //VolumeSizingMode C: custom
  };

//ToDo: risk volume based (we need to know SL distance)


double getVolume(VolumeSizingMode volume_sizing, string symbol, double master_vol)
{
  double volume = g_FX_FixedVolume_setting;

  if (volume_sizing == VolumeSizingMode_MS) { // MS: Master
    volume = g_MS_VolumeRatio_setting * master_vol;  
  } else if (volume_sizing == VolumeSizingMode_FX) { // FX: fixed
    volume = g_FX_FixedVolume_setting;
  /*
  } else if (g_VolumeSizingMode == VolumeSizingMode_BP) { // BP: balance pcnt
    volume = AccountBalance()/g_BP_BalanceBasis * g_BP_BalancePcnt/100.0;
  } else if (g_VolumeSizingMode == VolumeSizingMode_EP) { // EP: equity pcnt
    volume = AccountEquity()/g_EP_EquityBasis * g_EP_EquityPcnt/100.0;
  } else if (g_VolumeSizingMode == VolumeSizingMode_FMP) { // FMP: free margin pcnt
    volume = AccountFreeMargin()/g_FMP_FreeMarginBasis * g_FMP_FreeMarginPcnt/100.0;
  */
  } else if (volume_sizing == VolumeSizingMode_C) { // C: custom
    volume = 0.02;
    return (volume);
  }
    
  double max_volume = MathMin(MarketInfo(symbol, MODE_MAXLOT), g_MaxVolume_setting);
  double min_volume = MathMax(MarketInfo(symbol, MODE_MINLOT), g_MinVolume_setting);

  if (volume < min_volume) volume = min_volume;
  if (volume > max_volume) volume = max_volume;
  
  int lot_digits = VolumeDigits(symbol);
  volume = NormalizeDouble(volume, lot_digits);
  
  return (volume);
}

