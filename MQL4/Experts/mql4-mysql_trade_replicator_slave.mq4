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
#include <mql4-mysql_trade_replicator_slave.mqh>


extern int g_timezone_setting = 3; //server time zone
   // ask your broker for the correct value
   //if broker obeys daylight savings
   //you have to change this setting manually when dst is in effect
   //format should be like this (offset in numerical form): +00 (meaning GMT, +01 = GMT+1, etc.)

//extern string g_timezone_setting = "your_broker_time_zone"; //server time zone - ask your broker for the correct value
                                                            //if broker obeys daylight savings
                                                            //you have to change this setting manually when dst is in effect
                                                            //format should be like this (offset in numerical form): +00 (meaning GMT, +01 = GMT+1, etc.)

extern string g_slave_id_setting = "fVB472V9x8i4RN081pg8"; //slave_id - a string of 20 symbols recommended id, use some passwords generator to obtain it http://strongpasswordgenerator.com/
extern string g_deposit_currency_setting = "USD"; //deposit currency
extern string g_slave_comment_setting = "slave01"; //master comment

extern int g_max_slippage_setting = 10; //max splippage (points not pips)

//ToFix
//extern double g_trade_scale = 1; //volume multiplier, master lots will be multiplied by it and the result used for the copied trade opening

//extern bool g_reverse_trades = false; //invert the direction of the master trade or not
//extern double g_trade_scale = 1; //volume multiplier, master lots will be multiplied by it and the result used for the copied trade opening

extern string g_subscribed_masters_setting = "n9o816RTuaxJt99WSfD8"; //subscribed_masters is a list of masters in the form "master1 master2 master3" etc. (blank space between each master)
//"n9o816RTuaxJt99WSfD8 xxk20J784328ro4U76sR H136QITL8710852rt4E6"; 

extern string  g_table_prefix_setting = "trade_replicator_"; //table prefix
//extern string  g_table_prefix = ""; //table prefix

extern int g_logging_level_setting = 0; //level of logging (0 display all - see toolbox code)

input CopyMode   g_copy_mode_setting = CopyMode_Follow; //CopyMode - define how trade are copied
input VolumeSizingMode   g_volume_sizing_mode_setting = VolumeSizingMode_MS; //VolumeSizingMode - define volume on slave trades

input double   g_MS_VolumeRatio_setting = 1.0; //MS_VolumeRatio - master volume ratio

input double   g_FX_FixedVolume_setting = 0.01; //FX_FixedVolume - fixed volume

//extern double   g_BP_BalancePcnt = 1.00; //BP_BalancePcnt
//extern double   g_BP_BalanceBasis = 1000.0; //BP_BalanceBasis

//extern double   g_EP_EquityPcnt = 1.50; //EP_EquityPcnt - fee equity percent
//extern double   g_EP_EquityBasis = 1000.0; //EP_EquityBasis

//extern double   g_FMP_FreeMarginPcnt = 2.0; //FMP_FreeMarginPcnt - free margin percent
//extern double   g_FMP_FreeMarginBasis = 1000.0; //FMP_FreeMarginBasis

input double   g_MinVolume_setting = 0.01; //MinVolume
input double   g_MaxVolume_setting = 1.0; //MaxVolume

input double g_price_offset_setting = 0.8; //price_offset (pips)

input int g_number_of_trials_setting = 10; //number of trials for open or close orders

extern bool g_drop_tables_setting = false; //drop tables (set to True to drop database tables)
extern bool g_create_tables_setting = false; //create tables (set to True only first time to create database tables)
extern bool g_register_slave_setting = true; //register slave to DB (set to True only first time you use a new master)

//string g_current_master_id = ""; // ToFix! is it necessary to be global ?


// ---



/*
int tokenize_masters()
{
    ArrayResize(g_master_ids, 0);
    SplitString(g_subscribed_masters, " ", g_master_ids);
    
    return (ArraySize(g_master_ids));
}
*/
//StringSplit(g_subscribed_masters, " ", g_master_ids);


// --




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---  
    init_table_names(g_table_prefix_setting);

    string master_ids[];
    int masters_count = StringSplit(g_subscribed_masters_setting, ' ', master_ids);
    logging(INFO_LEVEL, "Subscribed to " + IntegerToString(masters_count) + " masters.");
    
    for (int cur_master = 0 ; cur_master < masters_count ; cur_master++) {
       logging(INFO_LEVEL, "Subscribed master: " + master_ids[cur_master]);
    }

    if (!connect_db(g_db_connect_id, g_db_host_setting, g_db_user_setting, g_db_pass_setting, g_db_name_setting, g_db_port_setting, g_db_socket_setting, g_db_client_setting))
        return (INIT_FAILED);

    if (g_drop_tables_setting) {
        if (!drop_table_replicator(g_db_connect_id, g_db_name_setting, g_table_prefix_setting)) {
            logging(CRITICAL_LEVEL, "Can't drop tables");
        }    
    }

    if (g_create_tables_setting) {
        if ( !create_table_replicator(g_db_connect_id, g_db_name_setting, g_table_prefix_setting) ) {
            logging(CRITICAL_LEVEL, "can't create table for table replicator (tables maybe ever exists)");            
            //return(INIT_FAILED); // fail
        }
    }

    if (g_register_slave_setting) {
        if ( !register_slave(g_db_connect_id, g_slave_id_setting, g_deposit_currency_setting, g_slave_comment_setting) ) {
            logging(CRITICAL_LEVEL, "can't register master to trade replicator (this master_id maybe ever exists)");      
        }
    }

    MathSrand((int) TimeCurrent());

    datetime prev_time = TimeLocal();
    
    string current_master_id = "";
    
    bool flag_no_db_error = true;

    while (true)
    {
        if ((TimeLocal() - prev_time) >= 1) //Do stuff once per second
        {
            prev_time = TimeLocal();

            for (int i=0 ; i < masters_count; i++)
            {
                current_master_id = master_ids[i];
                
                //Print(current_master_id);

                if (get_trades_to_close(g_db_connect_id, current_master_id, g_slave_id_setting)) {
                    close_trades(g_db_connect_id, g_slave_id_setting);
                }

                if (get_trades_to_open(g_db_connect_id, current_master_id, g_slave_id_setting)) { //&& flag_no_db_error) {
                    Print("Open trade from master " + quote(current_master_id));
                    flag_no_db_error = flag_no_db_error && open_trades(g_db_connect_id, current_master_id, g_slave_id_setting, g_max_slippage_setting, g_copy_mode_setting, g_volume_sizing_mode_setting);
                }
            }
            
            //if (!flag_no_db_error) {
            //    logging(CRITICAL_LEVEL, "DB error - CAUTION!");
            //}
            Comment("OrderTotal: " + IntegerToString(OrdersTotal()) + " " + "opened trade in DB: " + IntegerToString(g_nb_opened_trades_in_db));
        }

        Sleep(500);
    }
    
    disconnect_db(g_db_connect_id);
   
    logging(INFO_LEVEL, "INIT_SUCCEEDED");
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
