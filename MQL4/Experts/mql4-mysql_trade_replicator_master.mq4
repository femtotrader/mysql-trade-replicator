//+------------------------------------------------------------------+
//|                           mql4-mysql_trade_replicator_master.mq4 |
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

#include <mql4-mysql.mqh>
#include <mql4-mysql_toolbox.mqh>
#include <mql4-mysql_config.mqh>
#include <mql4-mysql_trade_replicator.mqh>
#include <mql4-mysql_trade_replicator_master.mqh>

//extern string g_master_id_setting = "your_randomly_generated_master_id"; //20 symbols recommended id, use some passwords generator to obtain it
// http://strongpasswordgenerator.com/
extern string g_master_id_setting = "n9o816RTuaxJt99WSfD8";  //master_id - a string of 20 symbols recommended id, use some passwords generator to obtain it
extern string g_deposit_currency_setting = "USD"; //deposit currency
extern string g_master_comment_setting = "master01"; //master comment

extern string  g_table_prefix_setting = "trade_replicator_"; //table prefix

extern int g_logging_level_setting = 0; //level of logging (0 display all - see toolbox code)

extern bool g_drop_tables_setting = false; //drop tables (set to True to drop database tables)
extern bool g_create_tables_setting = false; //create tables (set to True only first time to create database tables)
extern bool g_register_master_setting = true; //register master to DB (set to True only first time you use a new master)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

    //bool synchronized = false; // Trades real and DB
    //bool synchronized_prev = false; // previous state

    init_table_names(g_table_prefix_setting);
    
    if (!connect_db(g_db_connect_id, g_db_host_setting, g_db_user_setting, g_db_pass_setting, g_db_name_setting, g_db_port_setting, g_db_socket_setting, g_db_client_setting))
        return (INIT_FAILED);

    if (g_drop_tables_setting) {
        if (!drop_table_replicator(g_db_connect_id, g_db_name_setting, g_table_prefix_setting)) {
            logging(CRITICAL_LEVEL, "Can't drop tables");
        }    
    }
    
    if (g_create_tables_setting) {
        if ( !create_table_replicator(g_db_connect_id, g_db_name_setting, g_table_prefix_setting) ) {
            logging(CRITICAL_LEVEL, "Can't create table for table replicator (tables maybe ever exists)");            
            //return(INIT_FAILED); // fail
        }
    }

    if (g_register_master_setting) {
        if ( !register_master(g_db_connect_id, g_master_id_setting, g_deposit_currency_setting, g_master_comment_setting) ) {
            logging(CRITICAL_LEVEL, "Can't register master to trade replicator (this master_id maybe ever exists)");      
        }
    }
        
    datetime prev_time = TimeLocal();

    while (true)
    {
        if ((TimeLocal() - prev_time) >= 1) //Do stuff once per second
        {
            prev_time = TimeLocal();
            
            //logging(DEBUG_LEVEL, "get_open_trades_from_db");
            get_open_trades_from_db(g_db_connect_id, g_master_id_setting);
            //logging(DEBUG_LEVEL, "find_closed_trades");
            find_closed_trades(g_db_connect_id, g_master_id_setting);

            //logging(DEBUG_LEVEL, "get_open_trades_from_db (2)");
            get_open_trades_from_db(g_db_connect_id, g_master_id_setting);
            //logging(DEBUG_LEVEL, "find_new_trades");
            find_new_trades(g_db_connect_id, g_master_id_setting);
            
            /*

            synchronized_prev = synchronized;
            if (g_nb_opened_trades_in_db == OrdersTotal()) {
                synchronized = true;
            } else {
                synchronized = false;
            }

            if ( (!synchronized && synchronized_prev) || (synchronized && !synchronized_prev) ) {
                logging(DEBUG_LEVEL, "opened trades - real/db - " + IntegerToString(OrdersTotal()) + "/" + IntegerToString(g_nb_opened_trades_in_db));
            }
            */
            Comment("OrderTotal: " + IntegerToString(OrdersTotal()) + " " + "opened trade in DB: " + IntegerToString(g_nb_opened_trades_in_db));

                        
        }

        Sleep(2000); // 500
    }
    
    disconnect_db(g_db_connect_id); 

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   disconnect_db(g_db_connect_id);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+

