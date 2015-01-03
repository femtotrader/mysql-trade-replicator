//+------------------------------------------------------------------+
//|                                       orders_to_send_manager.mqh |
//|                                    Copyright © 2014, FemtoTrader |
//|                       https://sites.google.com/site/femtotrader/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2014, FemtoTrader"
#property link      "https://sites.google.com/site/femtotrader/"
#property strict


#include <Object.mqh>
#include <display_price_volume.mqh>
#include <volume_sizing.mqh>
#include <logging_basic.mqh>

#define CMD_OPEN 0
#define CMD_CLOSE 1
// ask>bid => spread=ask-bid
// open buy at ask
// open sell at bid
// close buy at bid
// close sell at ask
double getPrice(int cmdOpenClose, int cmd, double bid, double ask, bool reverse=False) {
    double price = 0;
    int dir_sign = direction_sign(cmd);
    if(reverse) {
      dir_sign = -dir_sign;
    }
    
    if (cmdOpenClose==CMD_OPEN) {
        if (dir_sign>0) { // cmd==OP_BUY || cmd==OP_BUYLIMIT || cmd==OP_BUYSTOP
            price = ask;
        } else if (dir_sign<0) { // cmd==OP_SELL || cmd==OP_SELLLIMIT || cmd==OP_SELLSTOP
            price = bid;
        }
    } else if (cmdOpenClose==CMD_CLOSE) {
        if (dir_sign>0) {
            price = bid;
        } else if (dir_sign<0) {
            price = ask;
        }    
    }
    return(price);
}

bool is_pending_order(int cmd) {
   return(cmd>=2);
}

bool is_market_order(int cmd) {
   return(cmd<2); // 0:OP_BUY 1:OP_SELL
}

int direction_sign(int order_type) {
    if (order_type==OP_BUY || order_type==OP_BUYLIMIT || order_type==OP_BUYSTOP) {
        return(1);
    } else if (order_type==OP_SELL || order_type==OP_SELLLIMIT || order_type==OP_SELLSTOP) {
        return(-1);
    } else {
        return(0);
    }
}

string OrderTypeToString(int order_type) {
    if (order_type==OP_BUY) {
        return("__BUY___");
    } else if (order_type==OP_SELL) {
        return("__SELL__");
    } else if (order_type==OP_BUYLIMIT) {
        return("BUYLIMIT");
    } else if (order_type==OP_SELLLIMIT) {
        return("SELLLIMIT");
    } else if (order_type==OP_BUYSTOP) {
        return("BUYSTOP");
    } else if (order_type==OP_SELLSTOP) {
        return("SELLSTOP");
    } else {
        return("??ORDER?");
    }
}



class MyOrder : CObject {
public:
   string m_symbol;
   int m_cmd;
   double m_volume;
   double m_price;
   int m_slippage;

   double m_stoploss;
   double m_takeprofit;
   
   datetime m_expiration;
   
   string m_comment;
   int m_magic;
   
   color m_arrow_color;
   
   MyOrder(
      string   symbol="",           // symbol
      int      cmd=OP_BUY,          // operation
      double   volume=0.0,          // volume
      double   price=0.0,           // price
      int      slippage=0,          // slippage
      double   stoploss=0.0,        // stop loss
      double   takeprofit=0.0,      // take profit
      string   comment=NULL,        // comment
      int      magic=0,             // magic number
      datetime expiration=0,        // pending order expiration   
      color    arrow_color=clrNONE  // color
      ) {  // constructor
      m_symbol = symbol;
      m_cmd = cmd;
      m_volume = volume;
      m_price = price;
      m_slippage = slippage;
      m_takeprofit = takeprofit;
      m_stoploss = stoploss;
      m_expiration = expiration;
      m_comment = comment;
      m_magic = magic;
      
      m_arrow_color = arrow_color;
   }
   
   int send() {
      return(OrderSend(m_symbol, m_cmd, m_volume, m_price, m_slippage, m_stoploss, m_takeprofit, m_comment, m_magic, m_expiration, m_arrow_color)); 
   }
   
   void update_price(double bid, double ask) {
      Print("Update price to bid=", bid, " ask=", ask);
      if ( m_cmd==OP_BUY ) {
         m_price = ask;
      } else if ( m_cmd==OP_SELL ) {
         m_price = bid;
      } else {
         Print("updating not supported for order type ", m_cmd);
      }      
   }

   string ToString(string sep=" ")
   {
      double pippoint = PipPoint(m_symbol);
      int digits_price = (int) MarketInfo(m_symbol, MODE_DIGITS);
      string s = "";
      //digits_price--; // test only
      s = OrderTypeToString(m_cmd) + sep
         //+ DoubleToString(m_volume, VolumeDigits(m_symbol)) + sep
         + VolumeToString(m_volume, m_symbol) + sep
         + m_symbol + sep //+ "@"
         //+ DoubleToString(m_price, digits_price) + sep 
         + PriceToString(m_price, m_symbol) + sep 
         //+ "SL=" + DoubleToString(m_stoploss, digits_price) + " (" + DoubleToString(getSL_dist()/pippoint, 1) + " pips" + ")" + sep
         + "SL=" + PriceToString(m_stoploss, m_symbol) + " (" + PriceDiffToPipsString(getSL_dist(), m_symbol) + ")" + sep
         //+ "TP=" + DoubleToString(m_takeprofit, digits_price) + " (" + DoubleToString(getTP_dist()/pippoint, 1) + " pips" + ")" + sep
         + "TP=" + PriceToString(m_takeprofit, m_symbol) + " (" + PriceDiffToPipsString(getTP_dist(), m_symbol) + ")" + sep
         + "\"" + m_comment + "\"" + sep + IntegerToString(m_magic)
         ;
      return(s);
   }
   
   int getDirectionSign() {
      return(direction_sign(m_cmd));
   }
   
   double getSL_dist() {
      return(MathAbs(m_price-m_stoploss));
   }

   double getTP_dist() {
      return(MathAbs(m_takeprofit-m_price));
   }

};


enum CopyMode
  {
   CopyMode_Follow    =  0,    //Follow (same direction)
   CopyMode_Reverse   =  1,    //Reversed
   CopyMode_Reverse2  =  2,    //Reversed only market orders and changed to pending orders   
//   CopyMode_Custom    =  3,    //Custom  
  };


bool order_copy(CopyMode copy_mode, MyOrder & order_from, MyOrder & order_to, double price, double bid, double ask, VolumeSizingMode vol_sizing, bool pending_with_same_price, double price_offset) {
   if (copy_mode == CopyMode_Follow) {
      return(order_copy_follow(order_from, order_to, price, bid, ask, vol_sizing));
   } else if (copy_mode == CopyMode_Reverse) {  
      return(order_copy_reverse(order_from, order_to, price, bid, ask, vol_sizing, pending_with_same_price, price_offset));
   } else if (copy_mode == CopyMode_Reverse2) {
      return(order_copy_reverse_only_market_orders(order_from, order_to, price, bid, ask, vol_sizing, pending_with_same_price, price_offset));
   } else {      
      Print("Unsupported copy mode ", copy_mode);
      return(False);
   }
}


// ====================================================================

bool order_copy_follow(MyOrder & order_from, MyOrder & order_to, double price, double bid, double ask, VolumeSizingMode vol_sizing) {

   order_to.m_symbol       = order_from.m_symbol;
   order_to.m_cmd          = order_from.m_cmd;
   order_to.m_volume       = getVolume(vol_sizing, order_from.m_symbol, order_from.m_volume);
   order_to.m_price        = order_from.m_price;
   order_to.m_slippage     = order_from.m_slippage;
   order_to.m_takeprofit   = order_from.m_takeprofit;
   order_to.m_stoploss     = order_from.m_stoploss;
   order_to.m_expiration   = order_from.m_expiration;
   order_to.m_comment      = order_from.m_comment;
   order_to.m_magic        = order_from.m_magic;

   order_to.m_comment = "[FOLLOW] " + order_from.m_comment;
   return(True);
}

// ====================================================================

bool order_copy_reverse(MyOrder & order_from, MyOrder & order_to, double price, double bid, double ask, VolumeSizingMode vol_sizing, bool pending_with_same_price, double price_offset) {

   order_to.m_symbol       = order_from.m_symbol;   
   order_to.m_volume       = getVolume(vol_sizing, order_from.m_symbol, order_from.m_volume);
   order_to.m_slippage     = order_from.m_slippage;
   order_to.m_expiration   = order_from.m_expiration;
   
   double pippoint = PipPoint(order_to.m_symbol);

   int cmd = order_from.m_cmd;
   if (cmd==OP_BUY) {
      order_to.m_cmd = OP_SELL;
      
   } else if (cmd==OP_SELL) {
      order_to.m_cmd = OP_BUY; 
      
   } else if (cmd==OP_BUYLIMIT) {
      order_to.m_cmd = OP_SELLSTOP;
      
   } else if (cmd==OP_SELLLIMIT) {
      order_to.m_cmd = OP_BUYSTOP;
      
   } else if (cmd==OP_BUYSTOP) {
      order_to.m_cmd = OP_SELLLIMIT;
      
   } else if (cmd==OP_SELLSTOP) {
      order_to.m_cmd = OP_BUYLIMIT; 
      
   } else {
      return(False); // NotImplemented
   }
   
   int dir_sign_from = direction_sign(order_from.m_cmd); 
   int dir_sign_to   = -dir_sign_from; //direction_sign(order_to.m_cmd); 
   
   //double price = order_from.m_price;
   order_to.m_price = getPrice(CMD_OPEN, order_to.m_cmd, bid, ask, pending_with_same_price) - dir_sign_to*price_offset;
   
   double takeprofit = order_from.m_takeprofit;
   double takeprofit_new;
   if (takeprofit!=0.0) {
      double takeprofit_dist = order_from.getTP_dist(); //dir_sign_from * (takeprofit - order_from.m_price);
      //Print("dTP= ", DoubleToString(takeprofit_dist/pippoint, 1), " pips");
      takeprofit_new = order_to.m_price + dir_sign_to * takeprofit_dist;
      if(takeprofit_new<0.0) {
         takeprofit_new = 0.0;
         logging(WARNING_LEVEL, "TAKEPROFIT can't be negative - set to 0.0");
      }
      order_to.m_takeprofit = takeprofit_new;
   } else {
      order_to.m_takeprofit = 0.0;
   }

   double stoploss = order_from.m_stoploss;
   double stoploss_new;
   if (stoploss!=0.0) {
      double stoploss_dist = order_from.getSL_dist(); //dir_sign_from * (order_from.m_price - stoploss);
      stoploss_new = order_to.m_price - dir_sign_to * stoploss_dist;
      if(stoploss_new<0.0) {
         stoploss_new = 0.0;
         logging(WARNING_LEVEL, "STOPLOSS can't be negative - set to 0.0");
      }
      order_to.m_stoploss = stoploss_new;
      //Print("dSL= ", DoubleToString(stoploss_dist/pippoint, 1), " pips");
   } else {
      order_to.m_stoploss = 0.0;
   }

   order_to.m_comment = "[REV1] " + order_from.m_comment;

   order_to.m_magic        = order_from.m_magic;

   return(True);
}

// ====================================================================

bool order_copy_reverse_only_market_orders(MyOrder & order_from, MyOrder & order_to, double price, double bid, double ask, VolumeSizingMode vol_sizing, bool pending_with_same_price, double price_offset) {
   order_to.m_symbol       = order_from.m_symbol;   
   order_to.m_volume       = getVolume(vol_sizing, order_from.m_symbol, order_from.m_volume);
   order_to.m_slippage     = order_from.m_slippage;
   order_to.m_expiration   = order_from.m_expiration;
   
   double pippoint = PipPoint(order_to.m_symbol);

   int cmd = order_from.m_cmd;
   if (cmd==OP_BUY) {
      order_to.m_cmd = OP_SELLLIMIT;
      
   } else if (cmd==OP_SELL) {
      order_to.m_cmd = OP_BUYLIMIT; 

   } else {
      return(False); // NotImplemented
   }
   
   int dir_sign_from = direction_sign(order_from.m_cmd); 
   int dir_sign_to   = -dir_sign_from; //direction_sign(order_to.m_cmd); 
   
   //double price = order_from.m_price;
   order_to.m_price = getPrice(CMD_OPEN, order_to.m_cmd, bid, ask, pending_with_same_price) - dir_sign_to*price_offset;
   
   double takeprofit = order_from.m_takeprofit;
   double takeprofit_new;
   if (takeprofit!=0.0) {
      double takeprofit_dist = order_from.getTP_dist(); //dir_sign_from * (takeprofit - order_from.m_price);
      //Print("dTP= ", DoubleToString(takeprofit_dist/pippoint, 1), " pips");
      takeprofit_new = order_to.m_price + dir_sign_to * takeprofit_dist;
      if(takeprofit_new<0.0) {
         takeprofit_new = 0.0;
         logging(WARNING_LEVEL, "TAKEPROFIT can't be negative - set to 0.0");
      }
      order_to.m_takeprofit = takeprofit_new;
   } else {
      order_to.m_takeprofit = 0.0;
   }

   double stoploss = order_from.m_stoploss;
   double stoploss_new;
   if (stoploss!=0.0) {
      double stoploss_dist = order_from.getSL_dist(); //dir_sign_from * (order_from.m_price - stoploss);   
      stoploss_new = order_to.m_price - dir_sign_to * stoploss_dist;
      if(stoploss_new<0) {
         stoploss_new = 0.0;
         logging(WARNING_LEVEL, "STOPLOSS can't be negative - set to 0.0");
      }
      order_to.m_stoploss = stoploss_new;
      //Print("dSL= ", DoubleToString(stoploss_dist/pippoint, 1), " pips");
   } else {
      order_to.m_stoploss = 0.0;
   }

   order_to.m_comment = "[REV2] " + order_from.m_comment;

   order_to.m_magic        = order_from.m_magic;

   return(True);
}