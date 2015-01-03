//+------------------------------------------------------------------+
//|                           mql4-mysql_trade_replicator_master.mqh |
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

#include <string_toolbox.mqh>
#include <mql4-mysql_trade_replicator.mqh>

bool register_master(int db_connect_id, string master_id, string deposit_currency, string comment) {
    return(register(db_connect_id, g_table_name_terminals_master, "master", master_id, deposit_currency, comment)); // exit success
}

void get_open_trades_from_db(int db_connect_id, string master_id) // master
{
    //string query = "SELECT * FROM " + g_table_name_trades_master + " WHERE close_time=0 AND master_id = '" + master_id + "';";
    string query = StringFormat("SELECT * FROM %s WHERE close_time=0 AND master_id = '%s'", g_table_name_trades_master, master_id);
    int result;
    string data[][NB_COLS_MASTER_TRADES];  // important: second dimension size must be equal to the number of columns
    //logging(DEBUG_LEVEL, query);
    result = MySQL_FetchArray(db_connect_id, query, data);
    //logging(DEBUG_LEVEL, "Query done with result=" + IntegerToString(result));

    if ( result == 0 ) {
        //logging(DEBUG_LEVEL, "0 rows selected");
        g_nb_opened_trades_in_db = 0;
    } else if ( result == -1 ) {
        logging(CRITICAL_LEVEL, "some error occured");
        g_nb_opened_trades_in_db = 0;
    } else {
        g_nb_opened_trades_in_db = ArrayRange(data, 0); // trades_count
        //int num_fields = ArrayRange(data, 1); // number of columns
        //logging(DEBUG_LEVEL, "Query was successful. Printing rows... (" + IntegerToString(num_rows) + "x" + IntegerToString(num_fields) + ")");

        ArrayResize(g_trade_ids, g_nb_opened_trades_in_db);
        //ArrayResize(g_trades, g_nb_opened_trades_in_db);

        for ( int i = 0; i < g_nb_opened_trades_in_db; i++) {
            //string line = "";
            //for ( int j = 0; j < num_fields; j++ ) {
            //    string value = data[i][j];
            //    line = StringConcatenate(line, value, ";");
            //}
            //logging(DEBUG_LEVEL, IntegerToString(i) + " - " + line);
            g_trade_ids[i] = data[i][8];
        }
    }
    //return(g_nb_opened_trades_in_db>0);
}

//trade close event to DB
void on_trade_close(int db_connect_id, string master_id, int order)
{
    logging(DEBUG_LEVEL, "Writing trade close to DB for order #" + IntegerToString(order));

    if (!OrderSelect(order, SELECT_BY_TICKET, MODE_HISTORY))
    {
        logging(CRITICAL_LEVEL, "ERROR: cannot select order " + IntegerToString(order));
        return;
    }

    double close_price = OrderClosePrice();
    string close_time = create_db_timestamp(OrderCloseTime());
    int trade_id = OrderTicket();
    double stop_loss = OrderStopLoss();
    double take_profit = OrderTakeProfit();
    double profit = OrderProfit();
    double swaps = OrderSwap();
    
    string sep = ", ";
    string query = "UPDATE " + g_table_name_trades_master + " SET stop_loss="
        + DoubleToStr(stop_loss, g_digits) + sep + "take_profit=" + DoubleToStr(take_profit, g_digits) + sep
        + "close_time=" + quote(close_time) + sep + "close_price=" + DoubleToStr(close_price, g_digits) + sep
        + "profit=" + DoubleToStr(profit, g_digits) + sep + "swaps=" + DoubleToStr(swaps, g_digits)
        + " WHERE (master_id=" + quote(master_id) + ") AND (trade_id=" + quote(IntegerToString(trade_id)) + ");";
    //string query = StringFormat("UPDATE %s SET stop_loss=%s, take_profit=%s, close_time=%s, close_price=%s, profit=%s, swaps=%s WHERE (master_id='%s') AND (trade_id='%s');", g_tableName_trades_master, DoubleToStr(stop_loss, g_digits), DoubleToStr(take_profit, g_digits), close_time, DoubleToStr(close_price, g_digits), DoubleToStr(profit, g_digits), DoubleToStr(swaps, g_digits), master_id, IntegerToString(trade_id));

    logging(DEBUG_LEVEL, query);
    int result = MySQL_Query(db_connect_id, query);

    if (!result)
    {
        logging(CRITICAL_LEVEL, "Can't update " + g_table_name_trades_master);
        //reconnect();
    }

}

//check all g_trade_ids and find closed, for each closed call on_trade_close() once
void find_closed_trades(int db_connect_id, string master_id)
{
    int trade_closed = 0;
    for (int i = 0; i < g_nb_opened_trades_in_db; i++)
    {
        if (is_trade_closed((int) StringToInteger(g_trade_ids[i])))
            on_trade_close(db_connect_id, master_id, (int) StringToInteger(g_trade_ids[i]));
            trade_closed = trade_closed + 1;
    }
    g_nb_opened_trades_in_db = g_nb_opened_trades_in_db - trade_closed;
    //ArrayResize(g_trade_ids, g_nb_opened_trades_in_db);
    //ArrayResize(g_trades, g_nb_opened_trades_in_db);
}


bool is_open_in_memory(string trade_id)
{
    for (int i = 0; i < g_nb_opened_trades_in_db; i++)
    {
        if (trade_id == g_trade_ids[i])
            return (true);
    }

    return (false);
}


void find_new_trades(int db_connect_id, string master_id)
{
    int total = OrdersTotal();
    //Print("OrdersTotal: ", total);

    for (int pos = 0; pos < total; pos++)
    {
        if (OrderSelect(pos, SELECT_BY_POS) == false) continue;
        
        //Print("OrderTicket: ", OrderTicket());
        //Print("OrderType: ", OrderType());
        if (OrderType() < 2)
        {
            if (!is_open_in_memory(IntegerToString(OrderTicket())))
                on_trade_open(db_connect_id, master_id, OrderTicket());
        }
    }
}



//trade open event to DB
void on_trade_open(int db_connect_id, string master_id, int order)
{
    logging(DEBUG_LEVEL, "Writing trade open to DB for order #" + IntegerToString(order));
    
    if (!OrderSelect(order, SELECT_BY_TICKET, MODE_TRADES))
    {
        logging(CRITICAL_LEVEL, "ERROR: cannot select order " + IntegerToString(order));
        return;
    }

    string instrument = OrderSymbol();
    int direction = OrderType();
    double volume = OrderLots();
    double open_price = OrderOpenPrice();
    string open_time = create_db_timestamp(OrderOpenTime());
    string close_time = create_db_timestamp(0); //"'0'";
    string comment = OrderComment();
       
    int trade_id = OrderTicket();
    double stop_loss = OrderStopLoss();
    double take_profit = OrderTakeProfit();
    double commission = OrderCommission();
    int magic_number = OrderMagicNumber();
    
    string sep = ", ";
    
    //INSERT IGNORE INTO ...
    string query = "INSERT INTO " + g_table_name_trades_master + " VALUES (" + quote(master_id) + sep
        + quote(instrument) + sep + IntegerToString(direction) + sep + DoubleToStr(volume, 5) + sep
        + DoubleToStr(open_price, 5) + sep + quote(open_time) + sep + quote(close_time) + sep + "NULL" + sep
        + quote(IntegerToString(trade_id)) + sep + DoubleToStr(stop_loss, 5) + sep
        + DoubleToStr(take_profit, 5)+ sep + DoubleToStr(commission, 5) + sep + "NULL" + sep
        + "NULL" + sep + quote(comment) + sep + IntegerToString(magic_number) + sep + "NULL" + sep + "NULL" + ");";
    logging(DEBUG_LEVEL, query);
    int result = MySQL_Query(db_connect_id, query);

    if (!result)
    {
        logging(CRITICAL_LEVEL, "Can't insert into " + g_table_name_trades_master);
        //reconnect();
    }
}
