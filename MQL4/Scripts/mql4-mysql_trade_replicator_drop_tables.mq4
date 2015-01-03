//+------------------------------------------------------------------+
//|                      mql4-mysql_trade_replicator_drop_tables.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#include <mql4-mysql.mqh>
#include <mql4-mysql_toolbox.mqh>
#include <mql4-mysql_config.mqh>
#include <mql4-mysql_trade_replicator.mqh>

extern string  g_tablePrefix = ""; //table prefix
extern int g_logging_level = 0; //level of logging (0 display all - see toolbox code)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---

    init_table_names(g_tablePrefix);
 
    if (connect_db(g_db_connect_id, g_db_host, g_db_user, g_db_pass, g_db_name, g_db_port, g_db_socket, g_db_client)) {
        if (!drop_table_replicator(g_db_connect_id, g_db_name, g_tablePrefix)) {
            Print("Can't drop tables");
        }
    } else {
        Print("Can't connect to DB");
    }
  }
//+------------------------------------------------------------------+

