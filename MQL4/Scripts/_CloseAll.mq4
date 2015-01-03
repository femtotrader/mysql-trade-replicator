//+------------------------------------------------------------------+
//|                                                    _CloseAll.mq4 |
//|                                    Copyright © 2014, FemtoTrader |
//|                       https://sites.google.com/site/femtotrader/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2014, FemtoTrader"
#property link      "https://sites.google.com/site/femtotrader/"
#property version   "1.00"
#property strict
#property show_inputs

extern int slippage = 3; //slippage (points)
extern int g_number_of_trials = 10; //number of trials for open or close orders

int number_orders_not_pending() {
    int total = OrdersTotal();
    int total_not_pending = 0;
    bool b_result;
    for ( int i=total-1; i>=0; i-- ) {
        b_result=OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if(OrderType()==OP_BUY || OrderType()==OP_SELL) {
            total_not_pending++;
        }
        
    }
    return(total_not_pending);
}

//+------------------------------------------------------------------+
//| script program start function                                    |
//+------------------------------------------------------------------+
int OnStart() {
    double price;
    int trials;
    int total = OrdersTotal();
    int total_not_pending = number_orders_not_pending();
    bool b_result;
    Print("There is " + IntegerToString(total) + " orders - " + IntegerToString(total_not_pending) + " not pending to close");  //Comment(...)
    for ( int i=total-1; i>=0; i-- ) {
        trials = 0;
        b_result = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

        b_result = false;
 
        if(OrderType()==OP_BUY || OrderType()==OP_SELL) {

            while( (!b_result) && (trials<g_number_of_trials) ) {
                if(OrderType() == OP_BUY) {
                    price = MarketInfo(OrderSymbol(), MODE_BID); //Bid;
                } else {
                    price = MarketInfo(OrderSymbol(), MODE_ASK); //Ask;
                }
                b_result = OrderClose(OrderTicket(), OrderLots(), price, slippage, CLR_NONE);
                Print("Trying to close order #" + IntegerToString(OrderTicket()) + " at " + DoubleToString(price));
                trials++;
                if (!b_result) {
                    Print("Can't close order #" + IntegerToString(OrderTicket()) + "(" + IntegerToString(trials) + ")");
                    RefreshRates();
                }
            }
        }
    }
    Print("Every not pending orders (" + IntegerToString(total_not_pending) + ") should be closed"); //Comment(...)
    return(0);
}
//+------------------------------------------------------------------+