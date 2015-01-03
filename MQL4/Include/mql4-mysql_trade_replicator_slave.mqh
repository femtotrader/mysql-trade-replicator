//+------------------------------------------------------------------+
//|                            mql4-mysql_trade_replicator_slave.mqh |
//|                           Trades replicator using MySQL database |
//|                                              Metatrader 4 master |
//|                                                                  |
//|                                    Copyright © 2014, FemtoTrader |
//|                       https://sites.google.com/site/femtotrader/ |
//|                                                                  |
//|                                Distributed under the BSD license |
//|                      http://opensource.org/licenses/BSD-2-Clause |
//|                                                                  |
//|                                   Inspired from trade_replicator |
//|                        https://github.com/kr0st/trade_replicator |
//|                                                                  |
//|                                                     Dependencies |
//|             mql4-mysql https://github.com/sergeylukin/mql4-mysql |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2014, FemtoTrader"
#property link      "https://sites.google.com/site/femtotrader/"
#property version   "1.00"
#property strict

#include <mql4-mysql_trade_replicator.mqh>
#include <orders_to_send_manager.mqh>

bool register_slave(int db_connect_id, string slave_id, string deposit_currency, string comment) {
    return(register(db_connect_id, g_table_name_terminals_slave, "slave", slave_id, deposit_currency, comment)); // exit success
}


bool get_trades_to_open(int db_connect_id, string master_id, string slave_id) // slave
{
    string query = "SELECT * from " + g_table_name_trades_master + " WHERE master_id = " + quote(master_id)
        + " AND close_time=0 AND trade_id NOT IN (SELECT master_trade_id FROM " + g_table_name_trades_slave
        + " WHERE close_time=0 AND master_id = " + quote(master_id) + " AND slave_id = "
        + quote(slave_id) + ");";
    //logging(DEBUG_LEVEL, query);
    int result;
    string data[][NB_COLS_MASTER_TRADES];  // important: second dimension size must be equal to the number of columns
    result = MySQL_FetchArray(db_connect_id, query, data);
    
    if ( result == 0 ) {
        //logging(DEBUG_LEVEL, "0 rows selected");
        g_nb_opened_trades_in_db = 0;
    } else if ( result == -1 ) {
        logging(CRITICAL_LEVEL, "some error occured");
        g_nb_opened_trades_in_db = 0;
    } else {
        g_nb_opened_trades_in_db = ArrayRange(data, 0); // trades_count
        int num_fields = ArrayRange(data, 1); // number of columns
        //logging(DEBUG_LEVEL, "Query was successful. Printing rows... (" + IntegerToString(num_rows) + "x" + IntegerToString(num_fields) + ")");

        ArrayResize(g_trade_instrument, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_cmd, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_volume, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_open_price, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_ids, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_stoploss, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_takeprofit, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_comment, g_nb_opened_trades_in_db);
        ArrayResize(g_trade_magic_number, g_nb_opened_trades_in_db);
        
        for ( int i = 0; i < g_nb_opened_trades_in_db; i++) {
            // column index is master_trades column order
            //                                                 // 00: master_id
            g_trade_instrument[i] = data[i][1];                // 01: instrument
            g_trade_cmd[i] = StrToInteger(data[i][2]);         // 02: direction (cmd)
            g_trade_volume[i] = StrToDouble(data[i][3]);       // 03: volume
            g_trade_open_price[i] = StrToDouble(data[i][4]);   // 04: open_price
            //                                                 // 05: open_time
            //                                                 // 06: close_time
            //                                                 // 07: close_price
            g_trade_ids[i] = data[i][8];                       // 08: trade_id
            g_trade_stoploss[i] = StrToDouble(data[i][9]);     // 09: stop_loss
            g_trade_takeprofit[i] = StrToDouble(data[i][10]);  // 10: take_profit
            //                                                 // 11: commission
            //                                                 // 12: profit
            //                                                 // 13: swap
            g_trade_comment[i] = data[i][14];
            g_trade_magic_number[i] = (int) StringToInteger(data[i][15]);
            //                                                 // 16: created
            //                                                 // 17: updated
        }
    }
    
    return(g_nb_opened_trades_in_db>0);
}


bool slave_open_trade_to_db(int db_connect_id, string master_id, string slave_id, int index, int status)
{
    string status_text = "NULL";
    string open_time = create_db_timestamp(0);
    string close_time = create_db_timestamp(0);
    string slave_trade_id = "NULL";
    double stop_loss = 0;
    double take_profit = 0;
    double commission = 0;

    Print("Status = ", status);
    
    if (status == ERR_NO_ERROR)
    {
        status_text = "NULL";
        open_time = create_db_timestamp(OrderOpenTime());
        slave_trade_id = IntegerToString(OrderTicket());
        stop_loss = OrderStopLoss();
        take_profit = OrderTakeProfit();
        commission = OrderCommission();
    }
    else
    {
        status_text = quote(IntegerToString(status));
        open_time = create_db_timestamp(TimeCurrent());
        slave_trade_id = random_id();
    }

    Print("Status text = ", status_text);
    
    string master_trade_id = g_trade_ids[index];

    string instrument = g_trade_instrument[index];
    int direction = g_trade_cmd[index];
    double volume = g_trade_volume[index];
    double open_price = g_trade_open_price[index];
    string comment = g_trade_comment[index];
    int magic_number = g_trade_magic_number[index];
    
    // INSERT IGNORE?
    string sep = ", ";
    string query = "INSERT INTO " + g_table_name_trades_slave + " VALUES (" + quote(master_id) + sep
        + quote(instrument) + sep + IntegerToString(direction) + sep + DoubleToStr(volume, 5) + sep
        + DoubleToStr(open_price, 5) + sep + quote(open_time) + sep + quote(close_time) + sep
        + "NULL" + sep + quote(master_trade_id) + sep + DoubleToStr(stop_loss, 5) + sep
        + DoubleToStr(take_profit, 5)+ sep + quote(slave_id) + sep + quote(slave_trade_id) + sep
        + DoubleToStr(commission, 5) + sep + "0" + sep + "0" + sep + quote(comment) + sep + IntegerToString(magic_number) + sep
        + status_text + sep + "NULL" + sep + "NULL" + ");";
    logging(DEBUG_LEVEL, query);
    int result = MySQL_Query(db_connect_id, query);

    if (!result)
    {
        logging(CRITICAL_LEVEL, "Can't insert " + g_table_name_trades_slave);
        return(false);
        //reconnect();
    } else {
        return(true);
    }
}


bool open_trades(int db_connect_id, string master_id, string slave_id, int max_slippage, CopyMode copy_mode, VolumeSizingMode volume_sizing_mode)
{
    //Take into account slippage, trade reverse, correctly multiply by scale and round lots, round price to the last significant digit for the symbol on this server
    int status = 0;
    bool b_result_all = true;
    bool b_result;

    for (int i = 0; i < g_nb_opened_trades_in_db; i++)
    {
        status = open_trade(i, max_slippage, copy_mode, volume_sizing_mode);
        b_result = slave_open_trade_to_db(db_connect_id, master_id, slave_id, i, status); // b_result
        b_result_all = b_result_all && b_result;
        //if(!b_result) {
        //    logging(CRITICAL_LEVEL, "open trade error with slave_id=" + slave_id);
        //}
    }
    return(b_result_all);
}



bool get_trades_to_close(int db_connect_id, string master_id, string slave_id) // slave
{
    string sep = ", ";
    string query = "SELECT st.slave_trade_id FROM " + g_table_name_trades_slave + " st" + sep
        + g_table_name_trades_master + " mt WHERE st.master_id = " + quote(master_id)
        + " AND st.slave_id = " + quote(slave_id) + " AND st.close_time=0 AND st.status IS NULL"
        + " AND st.master_trade_id = mt.trade_id and mt.close_time!=0;";
    //logging(DEBUG_LEVEL, query);

    int result;
    string data[][1];  // important: second dimension size must be equal to the number of columns
    //logging(DEBUG_LEVEL, query);
    result = MySQL_FetchArray(db_connect_id, query, data);
    //logging(DEBUG_LEVEL, "Query done with result=" + IntegerToString(result));

    if ( result == 0 ) {
        //logging(DEBUG_LEVEL, "0 rows selected");
        g_nb_trades_to_close = 0;
    } else if ( result == -1 ) {
        logging(CRITICAL_LEVEL, "some error occured");
        g_nb_trades_to_close = 0;
    } else {
        g_nb_trades_to_close = ArrayRange(data, 0); // trades_count
        //logging(DEBUG_LEVEL, "Query was successful. Printing rows... (" + IntegerToString(num_rows) + "x" + IntegerToString(num_fields) + ")");

        ArrayResize(g_trade_to_close_ids, g_nb_trades_to_close);
        //ArrayResize(g_trades, g_nb_opened_trades_in_db);

        for ( int i = 0; i < g_nb_trades_to_close; i++) {
            g_trade_to_close_ids[i] = data[i][0];
        }
    }

    return(result>0);
}


int open_trade(int index, int max_slippage, CopyMode copy_mode, VolumeSizingMode volume_sizing_mode)
{
   int cmd = g_trade_cmd[index];
   string symb = g_trade_instrument[index];
   double volume = g_trade_volume[index];
   double price = g_trade_open_price[index];
   string comment = g_trade_comment[index];
   double stoploss = g_trade_stoploss[index];
   double takeprofit = g_trade_takeprofit[index];

   double pippoint = PipPoint(symb);
   double bid = 0.0;
   double ask = 0.0;
      
   MyOrder order_master(symb, cmd, volume, price, max_slippage, stoploss, takeprofit, comment);

   update_price(order_master.m_symbol, bid, ask);

   MyOrder order_slave;
   //MyOrder order_slave(symb, cmd, volume, price, max_slippage, stoploss, takeprofit, comment);
   
   
   order_copy(copy_mode, order_master, order_slave, price, bid, ask, volume_sizing_mode, true, g_price_offset_setting*pippoint); // , 0.0008
   
   
   RefreshRates();
   int ticket = -1;
   
   int count = 0;
   while ((ticket == -1) && (count < g_number_of_trials_setting))
   {
       Print(order_slave.ToString());
       RefreshRates();
       update_price(order_slave.m_symbol, bid, ask);
       order_slave.update_price(bid, ask);
       ticket = order_slave.send();
       count++;
       //Print("try again... ", count + 1);
   } 

   if(ticket < 0) {
       int error = GetLastError();
       Print("ERROR: OrderSend failed with error #", error);
       return (error);
   }

    bool b_result = OrderSelect(ticket, SELECT_BY_TICKET);

    g_trade_volume[index] = OrderLots();
    g_trade_open_price[index] = OrderOpenPrice();

    return (ERR_NO_ERROR);
   
}


bool close_trade(int index)
{
    Print("Close trade #" + g_trade_to_close_ids[index]); // g_trade_ids or g_trade_to_close_ids
    
    //int ticket = (int) StringToInteger(g_trade_to_close_ids[index]);  // g_trade_ids or g_trade_to_close_ids
    int ticket = (int) StringToInteger(g_trade_to_close_ids[index]);
    
    if (is_trade_closed(ticket))
        return (true);
        
    bool b_result;

    b_result = OrderSelect (ticket, SELECT_BY_TICKET, MODE_TRADES);
    
    
    int cmd = OrderType();
    int error = -1;
    

    int count = 0;
    b_result = false;
    double price;
   
    if (cmd == OP_BUY || cmd == OP_SELL)
    {
        while ((!b_result) && (count < g_number_of_trials_setting))
        {
            RefreshRates();
            if(cmd == OP_BUY) {
                price = NormalizeDouble(MarketInfo(OrderSymbol(), MODE_BID), (int) MarketInfo(OrderSymbol(), MODE_DIGITS));
            } else { // OP_SELL
                price = NormalizeDouble(MarketInfo(OrderSymbol(), MODE_ASK), (int) MarketInfo(OrderSymbol(), MODE_DIGITS));
            }
            b_result = OrderClose(OrderTicket(), OrderLots(), price, 3, CLR_NONE);
            
            if(!b_result) {
                error = GetLastError();
                Print("LastError = ", error);
             } else {
                error = 0;
             }            
        }
    } else {
        logging(ERROR_LEVEL, "Can't 'close' pending orders need to 'delete' them");
        //break;
        return(false);
    }
    
    if (error != 0) {
        return (false);
    } else {
        return (true);
    }
}

bool close_trades(int db_connect_id, string slave_id)
{
    bool b_result = true;
    for (int i = 0; i < g_nb_trades_to_close; i++)
    {
        if (close_trade(i)) {
            b_result = b_result && slave_close_trade_to_db(db_connect_id, slave_id, i);
        }
    }
    return(b_result);
}


bool slave_close_trade_to_db(int db_connect_id, string slave_id, int index)
{    
    double close_price = OrderClosePrice();
    double profit = OrderProfit();
    double swaps = OrderSwap();
    string close_time = create_db_timestamp(TimeCurrent());
    
    Print("close_time = " + close_time);
    
    string sep = ", ";

    string query = "UPDATE " + g_table_name_trades_slave + " SET close_price=" + DoubleToStr(close_price, 5) + sep
        + "profit=" + DoubleToStr(profit, 5) + sep + "swaps=" + DoubleToStr(swaps, 5) + sep
        + "close_time=" + quote(close_time) + " WHERE slave_id=" + quote(slave_id)
        + " AND slave_trade_id=" + quote(g_trade_to_close_ids[index]) + ";";
    logging(DEBUG_LEVEL, query);
    
    int result;
    result = MySQL_Query(db_connect_id, query);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "update " + g_table_name_trades_slave + " failed");
        return(false); // fail
    } else {
        g_nb_trades_to_close = g_nb_trades_to_close - 1; //ToFix MT4 crash at close master -> close slave
        return(true); // exit success
    }    
}

