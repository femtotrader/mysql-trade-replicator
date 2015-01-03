//+------------------------------------------------------------------+
//|                                  mql4-mysql_trade_replicator.mqh |
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

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+

#include <mql4-mysql.mqh>
#include <mql4-mysql_toolbox.mqh>
#include <mql4-mysql_config.mqh>
#include <logging_basic.mqh>


//int g_logging_level = 0;
int     g_db_connect_id = 0;

string g_table_name_terminals_master;
string g_table_name_terminals_slave;
string g_table_name_trades_master;
string g_table_name_trades_slave;


// number of columns for each table
#define NB_COLS_MASTERS 5
#define NB_COLS_SLAVES 5
#define NB_COLS_MASTER_TRADES 18
#define NB_COLS_SLAVE_TRADES 21

//#define COL_MT_TRADE_ID 0
//#define COL_MT_TRADE_ID 0

int g_nb_opened_trades_in_db = 0;

string g_trade_ids[]; // string and not int in order to support not numeric trade_id (other master than MT4)

string g_trade_instrument[];
int g_trade_cmd[]; // 0=buy 1=sell 2=buylimit 3=selllimit 4=buystop 5=sellstop
double g_trade_volume[];
double g_trade_open_price[];
double g_trade_stoploss[];
double g_trade_takeprofit[];

string g_trade_comment[];
int g_trade_magic_number[];


string g_trade_to_close_ids[]; // string and not int in order to support not numeric trade_id (other master than MT4)
int g_nb_trades_to_close;

int g_digits = 5;


int write_string_to_file(string filename, string str)
{
    int file_handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI);
    int result = FileWriteString(file_handle, str+"\r\n");
    if (!result) {
        logging(CRITICAL_LEVEL, "can't write file '" + filename + "'");
    }
    FileClose(file_handle);
    return(result);
}

void init_table_names(string table_prefix) {
    g_table_name_terminals_master = table_prefix + "terminals_master";
    g_table_name_terminals_slave = table_prefix + "terminals_slave";
    g_table_name_trades_master = table_prefix + "trades_master";
    g_table_name_trades_slave = table_prefix + "trades_slave";
}

bool create_table_replicator(int db_connect_id, string db_name, string table_prefix)
{
    int result;
    //string tableName;
    string query;
    
    //---
    
    query =
"CREATE TABLE IF NOT EXISTS `" + db_name + "`.`" + g_table_name_terminals_master + "` (" +
"  `master_id` varchar(25) NOT NULL," +
"  `deposit_currency` varchar(10) NOT NULL," +
"  `comment` varchar(25) NOT NULL DEFAULT ''," +
"  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP," +
"  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP," +
"  PRIMARY KEY (`master_id`)" +
") ENGINE=InnoDB DEFAULT CHARSET=utf8;";
    logging(DEBUG_LEVEL, query);
    result = MySQL_Query(db_connect_id, query);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "query create table masters failed");
        //return(false); // fail
    }

    //---

    query =
"CREATE TABLE IF NOT EXISTS `" + db_name + "`.`" + g_table_name_terminals_slave + "` (" +
"  `slave_id` varchar(25) NOT NULL," +
"  `deposit_currency` varchar(10) NOT NULL," +
"  `comment` varchar(25) NOT NULL DEFAULT ''," +
"  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP," +
"  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP," +
"  PRIMARY KEY (`slave_id`)" +
") ENGINE=InnoDB DEFAULT CHARSET=utf8;";
    logging(DEBUG_LEVEL, query);
    result = MySQL_Query(db_connect_id, query);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "query create table masters failed");
        //return(false); // fail
    }
    
    //---

    query =
"CREATE TABLE IF NOT EXISTS `" + db_name + "`.`" + g_table_name_trades_master + "` (" +
"  `master_id` varchar(25) NOT NULL," +
"  `instrument` varchar(12) NOT NULL," +
"  `direction` int(11) NOT NULL," +
"  `volume` decimal(10,5) NOT NULL," +
"  `open_price` decimal(10,5) NOT NULL," +
"  `open_time` timestamp NOT NULL DEFAULT 0," +
"  `close_time` timestamp NOT NULL DEFAULT 0," +
"  `close_price` decimal(10,5) DEFAULT NULL," +
"  `trade_id` varchar(25) NOT NULL," +
"  `stop_loss` decimal(10,5) DEFAULT NULL," +
"  `take_profit` decimal(10,5) DEFAULT NULL," +
"  `commission` decimal(10,5) DEFAULT NULL," +
"  `profit` decimal(10,5) DEFAULT NULL," +
"  `swaps` decimal(10,5) DEFAULT NULL," +
"  `comment` varchar(25) NOT NULL DEFAULT ''," +
"  `magic_number` int(11) NOT NULL DEFAULT 0," +
"  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP," +
"  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP," +
"  PRIMARY KEY (`master_id`,`trade_id`)," +
"  CONSTRAINT `" + g_table_name_trades_master + "_master_id_fkey` FOREIGN KEY (`master_id`) REFERENCES `" + db_name + "`.`" + g_table_name_terminals_master + "` (`master_id`)" +
") ENGINE=InnoDB DEFAULT CHARSET=utf8;";
    logging(DEBUG_LEVEL, query);
    result = MySQL_Query(db_connect_id, query);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "query create table masters failed");
        //return(false); // fail
    }
    
    //---

    query =
"CREATE TABLE IF NOT EXISTS `" + db_name + "`.`" + g_table_name_trades_slave + "` (" +
"  `master_id` varchar(25) NOT NULL," +
"  `instrument` varchar(12) NOT NULL," +
"  `direction` int(11) NOT NULL," +
"  `volume` decimal(10,5) NOT NULL," +
"  `open_price` decimal(10,5) NOT NULL," +
"  `open_time` timestamp NOT NULL DEFAULT 0," +
"  `close_time` timestamp NOT NULL DEFAULT 0," +
"  `close_price` decimal(10,5) DEFAULT NULL," +
"  `master_trade_id` varchar(25) NOT NULL," +
"  `stop_loss` decimal(10,5) DEFAULT NULL," +
"  `take_profit` decimal(10,5) DEFAULT NULL," +
"  `slave_id` varchar(25) NOT NULL," +
"  `slave_trade_id` varchar(25) NOT NULL," +
"  `commission` decimal(10,5) DEFAULT NULL," +
"  `profit` decimal(10,5) DEFAULT NULL," +
"  `swaps` decimal(10,5) DEFAULT NULL," +
"  `comment` varchar(25) NOT NULL DEFAULT ''," +
"  `magic_number` int(11) NOT NULL DEFAULT 0," +
"  `status` text," +
"  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP," +
"  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP," +
"  PRIMARY KEY (`slave_id`,`slave_trade_id`)," +
"  KEY `" + g_table_name_trades_slave + "_master_id_fkey1` (`master_id`,`master_trade_id`)," +
"  CONSTRAINT `" + g_table_name_trades_slave + "_master_id_fkey` FOREIGN KEY (`master_id`) REFERENCES `" + db_name + "`.`" + g_table_name_terminals_master + "` (`master_id`)," +
"  CONSTRAINT `" + g_table_name_trades_slave + "_master_id_fkey1` FOREIGN KEY (`master_id`, `master_trade_id`) REFERENCES `" + db_name + "`.`" + g_table_name_trades_master + "` (`master_id`, `trade_id`)," +
"  CONSTRAINT `" + g_table_name_trades_slave + "_slave_id_fkey` FOREIGN KEY (`slave_id`) REFERENCES `" + db_name + "`.`" + g_table_name_terminals_slave + "` (`slave_id`)" +
") ENGINE=InnoDB DEFAULT CHARSET=utf8;";
    logging(DEBUG_LEVEL, query);
    result = MySQL_Query(db_connect_id, query);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "query create table masters failed");
        //return(false); // fail
    }

    //---
    
    return(true);

}

bool drop_table_replicator(int db_connect_id, string db_name, string table_prefix) {
   return( action_table_replicator(db_connect_id, db_name, table_prefix, "DROP"));
}

bool truncate_table_replicator(int db_connect_id, string db_name, string table_prefix) {
   return( action_table_replicator(db_connect_id, db_name, table_prefix, "TRUNCATE"));
}

bool action_table_replicator(int db_connect_id, string db_name, string table_prefix, string action="DROP")
{
    string query;
    int result;
    bool b_result = true;
    
    string a_tablename[];
    ArrayResize(a_tablename, 4);
    a_tablename[0] = g_table_name_trades_slave;
    a_tablename[1] = g_table_name_trades_master;
    a_tablename[2] = g_table_name_terminals_slave;
    a_tablename[3] = g_table_name_terminals_master;
    
    for (int i=0 ; i<4 ; i++) {
        query = StringFormat("%s TABLE `%s`.`%s`;", action, db_name, a_tablename[i]);
        logging(DEBUG_LEVEL, query);
        result = MySQL_Query(db_connect_id, query);
        if ( !result ) {
            logging(CRITICAL_LEVEL, "query " + action + " table failed");
            b_result = false;
            //return(false); // fail
        }
    }
    
    return(b_result);
}


bool register(int db_connect_id, string table_name, string terminal_type, string terminal_id, string deposit_currency, string comment) {
    string query;
    int result;
    query = StringFormat("INSERT INTO %s (%s_id, deposit_currency, comment, created, updated) VALUES ('%s', '%s', '%s', NULL, NULL) ON DUPLICATE KEY UPDATE comment=VALUES(comment), deposit_currency=VALUES(deposit_currency), updated=VALUES(updated);", table_name, terminal_type, terminal_id, deposit_currency, comment);
    logging(DEBUG_LEVEL, query);
    result = MySQL_Query(db_connect_id, query);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "insert " + table_name + " failed");
        return(false); // fail
    }    
    return(true); // exit success
}


bool connect_db(int & db_connect_id, string host, string user, string pass, string db_name, int port = 3306, int socket = 0, int client = 0)
{
    int result;
    result = init_MySQL(db_connect_id, host, user, pass, db_name, port, socket, client);
    if ( !result ) {
        logging(CRITICAL_LEVEL, "bad connection with MySQL database");
        return (false); // bad connect
    }
    return(true);
}


void update_price(string symb, double & bid, double & ask) {
   bid = NormalizeDouble(MarketInfo(symb, MODE_BID), (int) MarketInfo(symb, MODE_DIGITS));
   ask = NormalizeDouble(MarketInfo(symb, MODE_ASK), (int) MarketInfo(symb, MODE_DIGITS));
}


bool is_trade_closed(int order)
{
    return (OrderSelect(order, SELECT_BY_TICKET, MODE_HISTORY) && (OrderCloseTime() > 1000000000));
}


string random_id()
{
    string alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    string id = "1234567890123456789012345"; // 25 characters
    for (int i = 0; i < 25; i++)
    {
        ushort character = (ushort) MathRand() % 63;
        character = StringGetChar(alphabet, character);
        id = StringSetChar(id, i, character);
    }
    return (id);
}