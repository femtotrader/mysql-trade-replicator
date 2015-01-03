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

extern int slippage = 3;
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
    int trials;
    int total = OrdersTotal();
    int total_pending = total - number_orders_not_pending();
    bool b_result;
    Print("There is " + IntegerToString(total) + " orders - " + IntegerToString(total_pending) + " pending to delete");  //Comment(...)
    for (int i=total-1; i>=0; i-- ) {
        b_result = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

        b_result = false;
        if(OrderType()>=2) {
            trials = 0;
            while( (!b_result) && (trials<g_number_of_trials) ) {
                b_result = OrderDelete(OrderTicket(), CLR_NONE);
                Print("Trying to delete pending order #" + IntegerToString(OrderTicket()));
                trials++;
                if (!b_result) {
                    Print("Can't delete pending order #" + IntegerToString(OrderTicket()) + "(" + IntegerToString(trials) + ")");
                    RefreshRates();
                }
            }
        }
    }
    Print("Every not pending orders (" + IntegerToString(total_pending) + ") should be deleted");  //Comment(...)
    return(0);
}
//+------------------------------------------------------------------+