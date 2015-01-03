#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Python toolbox to manage trade_replicator MySQL database

    Copyright (C) 2014 "FemtoTrader" <femto.trader@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>

I'm developer and I provide under free software license some softwares that can be useful
for currencies users/traders.
If you consider that what I'm doing is valuable
you can send me some crypto-coins.
https://sites.google.com/site/femtotrader/donate
"""

import traceback
import logging
from collections import OrderedDict

import mysql.connector

ACTIONS_ALLOWED = ['create', 'drop', 'truncate', 'analyst']


def pip_position(symbol):
    if len(symbol) == 6:
        cur1 = symbol[0:3]
        cur2 = symbol[3:6]
        
        if cur2 == "JPY":
            return(2)
        else:
            return(4)
            
    else:
        raise(NotImplementedError)

"""
print 10**(-pip_position("EURUSD"))
print 10**(-pip_position("EURJPY"))
"""

d_order_type_str = {
    0: 'BUY',
    1: 'SELL',
    2: 'BUYLIMIT',
    3: 'BUYSTOP',
    4: 'SELLLIMIT',
    5: 'SELLSTOP',
}

from enum import Enum
ORDER_TYPE = Enum('BUY', 'SELL', 'BUYLIMIT', 'BUYSTOP', 'SELLLIMIT', 'SELLSTOP')

d_order_type_sign = {
	0: 1, # BUY
	1: -1, # SELL
    2: 1, # BUYLIMIT
    3: 1, # BUYSTOP
    4: -1, # SELLLIMIT
    5: -1, # SELLSTOP
}

# ???
#d_copy = {
#	0: 4, # BUY(Ask)->SELLLIMIT(Ask)
#	1: 2  # SELL(Bid)->BUYLIMIT(Bid)
#}

def title_string(s):
    return("="*5 + " " + s + " " + "="*5)

def get_db_conn(args):
    if args.dbengine.lower() == 'pgsql':
        import psycopg2
        logging.info("Connecting to PostgreSQL database")
        conn = psycopg2.connect(host=args.host, database=args.database,
                                user=args.user, password=args.password)
    elif args.dbengine.lower() == 'mysql':
        logging.info("Connecting to MySQL database")
        import mysql.connector
        conn = mysql.connector.connect(host=args.host, database=args.database,
                                user=args.user, password=args.password)
    else:
        raise(NotImplementedError)
    return(conn)

def tables_analyst(conn, tables_names, args):
    import pandas as pd
    
    masterid_algo = args.masterid_algo

    df_trades_master = pd.io.sql.read_sql("SELECT * FROM %s" % tables_names['trades_master'], conn)
    df_trades_slave = pd.io.sql.read_sql("SELECT * FROM %s" % tables_names['trades_slave'], conn)
    
    logging.info(title_string("trades_master"))
    df_trades_master['open_time'] = pd.to_datetime(df_trades_master['open_time'])
    df_trades_master['close_time'] = pd.to_datetime(df_trades_master['close_time'])
    df_trades_master['trade_duration'] = df_trades_master['close_time'] - df_trades_master['open_time']
    df_trades_master['pip_position'] = df_trades_master['instrument'].map(pip_position)
    df_trades_master['direction_str'] = df_trades_master['direction'].map(d_order_type_str)
    df_trades_master['direction_sign'] = df_trades_master['direction'].map(d_order_type_sign)
    #df_trades_master = df_trades_master.sort(columns=['open_time'], ascending=[True])
    #logging.info(df_trades_master.dtypes)
    cols = list(df_trades_master.columns)
    for i, col in enumerate(cols):
        cols[i] = "master" + '_' + col
            
    df_trades_master.columns = cols
    #df_trades_master = df_trades_master[::-1] # reverse order (last at head)
    #print(df_trades_master)
    df_trades_master = df_trades_master.sort(columns=['master_trade_id'], ascending=[True])
    logging.info("len: %d" % len(df_trades_master))
    logging.info("profit (master): %.2f" % df_trades_master['master_profit'].sum())
    #df_trades_master = df_trades_master.set_index('master_trade_id')
    df_trades_master.to_csv("trades_master.csv", sep=";")
    df_trades_master.to_excel("trades_master.xls")



    logging.info(title_string("trades_slave"))
    df_trades_slave['open_time'] = pd.to_datetime(df_trades_slave['open_time'])
    df_trades_slave['close_time'] = pd.to_datetime(df_trades_slave['close_time'])
    df_trades_slave['trade_duration'] = df_trades_slave['close_time'] - df_trades_slave['open_time']
    df_trades_slave['pip_position'] = df_trades_slave['instrument'].map(pip_position)
    df_trades_slave['direction_str'] = df_trades_slave['direction'].map(d_order_type_str)
    df_trades_slave['direction_sign'] = df_trades_slave['direction'].map(d_order_type_sign)
    #df_trades_slave = df_trades_slave.sort(columns=['open_time'], ascending=[True])
    #logging.info(df_trades_slave.dtypes)
    cols = list(df_trades_slave.columns)
    for i, col in enumerate(cols):
        if col != u"master_trade_id":
            cols[i] = 'slave' + '_' + col
    df_trades_slave.columns = cols
    #df_trades_slave = df_trades_slave[::-1] # reverse order (last at head)
    #print(df_trades_slave)
    df_trades_slave = df_trades_slave.sort(columns=['master_trade_id'], ascending=[True])
    logging.info("len: %d" % len(df_trades_slave))
    logging.info("profit (slave): %.2f" % df_trades_slave['slave_profit'].sum())
    #df_trades_slave = df_trades_slave.set_index('master_trade_id')
    #df_trades_slave.to_csv("trades_slave.csv", sep=";")
    df_trades_slave.to_excel("trades_slave.xls")
        
    df_merged = pd.merge(df_trades_master, df_trades_slave, on='master_trade_id', how='outer')    
    df_merged = df_merged.sort(columns=['master_open_time'], ascending=[True])
    
    df_merged['copy_dir'] = (1 + df_merged['master_direction_sign'] * df_merged['slave_direction_sign']) / 2
    
    for col in ['open_price', 'close_price', 'volume']: # 'open_time', 'close_time'
        df_merged['diff' + '_' + col] = df_merged['slave' + '_' + col] - df_merged['master' + '_' + col]
    
    # display pips
    df_merged['pip_position'] = df_merged['master_instrument'].map(pip_position)
    df_merged['pip_multiplier'] = 10**(df_merged['pip_position'])
    
    for col in ['open_price', 'close_price']:
	    df_merged["diff_{col}_pips".format(col=col)] = df_merged["diff_{col}".format(col=col)] * df_merged['pip_multiplier']
    

    # ToFix: we should add a column named "comment" into master table instead of this ugly hack
    d_masterid_algo = dict(key_val.split(':') for key_val in masterid_algo.split(','))
    df_merged['master_comment'] = ''
    try:
        df_merged['master_comment'] = df_merged['master_master_id'].map(d_masterid_algo)
    except:
    	logging.error(traceback.format_exc())


    cols = ['master_master_id', #'slave_master_id',
'slave_slave_id',
'master_comment',
'master_instrument', #'slave_instrument',
'master_direction', 'slave_direction',
'master_direction_str', 'slave_direction_str',
'copy_dir',
'master_volume', 'slave_volume',  'diff_volume',
'diff_open_price_pips', #'master_open_price', 'slave_open_price', 'diff_open_price_pips',
'master_open_time', 'slave_open_time', #'diff_open_time',
'master_close_time', 'slave_close_time', #'diff_close_time',
'diff_close_price_pips', #'master_close_price', 'slave_close_price', 'diff_close_price_pips',
'master_stop_loss', 'slave_stop_loss',
'master_take_profit', 'slave_take_profit',
'master_commission', 'slave_commission',
'master_profit', 'slave_profit',
'master_swaps', 'slave_swaps',
'master_trade_duration', 'slave_trade_duration',
'slave_slave_trade_id',
'master_trade_id', 
#'slave_slave_id',
'slave_status']

    df_merged = df_merged[cols]
    
    if args.slavetradesclosed:
    	df_merged = df_merged[df_merged['slave_close_time'].notnull()]

    if args.slavetradesopened:
    	df_merged = df_merged[df_merged['slave_close_time'].isnull()]
    
    #logging.info(df_merged)
    #df_merged.to_csv("merged.csv", sep=";")
    df_merged.to_excel("merged.xls")

    
    df_merged_grp_algo = pd.DataFrame(df_merged.groupby(['master_comment'])['slave_profit'].sum())
    logging.info(title_string("slave stats per algo (master_comment)")+"\n"+str(df_merged_grp_algo))
    df_merged_grp_algo.to_excel("merged_grp_algo.xls")

    logging.info(title_string("slave stats per algo and per trader (master_comment, trades_master_comment)")+"\n"+"ToDo")
    # ToDo: when we will have a column into trades_master with trader name (comment in trades_master) we will be able
    # to make df_merged.groupby(['master_comment', 'trades_master_comment'])['slave_profit']

def tables_create(conn, database, tables_prefix, tables_names):
    logging.info("Create tables")
    tables_queries = OrderedDict()

    tables_queries['terminals_master'] = """CREATE TABLE IF NOT EXISTS `{database}`.`{table}` (
  `master_id` varchar(25) NOT NULL,
  `deposit_currency` varchar(10) NOT NULL,
  `comment` varchar(25) NOT NULL DEFAULT '',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,  
  PRIMARY KEY (`master_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;""".format(database=database, table=tables_names['terminals_master'])

    #---

    tables_queries['terminals_slave'] = """CREATE TABLE IF NOT EXISTS `{database}`.`{table}` (
  `slave_id` varchar(25) NOT NULL,
  `deposit_currency` varchar(10) NOT NULL,
  `comment` varchar(25) NOT NULL DEFAULT '',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,  
  PRIMARY KEY (`slave_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;""".format(database=database, table=tables_names['terminals_slave'])
    
    #---

    tables_queries['trades_master'] = """CREATE TABLE IF NOT EXISTS `{database}`.`{table}` (
  `master_id` varchar(25) NOT NULL,
  `instrument` varchar(12) NOT NULL,
  `direction` int(11) NOT NULL,
  `volume` decimal(10,5) NOT NULL,
  `open_price` decimal(10,5) NOT NULL,
  `open_time` timestamp NOT NULL DEFAULT 0,
  `close_time` timestamp NOT NULL DEFAULT 0,
  `close_price` decimal(10,5) DEFAULT NULL,
  `trade_id` varchar(25) NOT NULL,
  `stop_loss` decimal(10,5) DEFAULT NULL,
  `take_profit` decimal(10,5) DEFAULT NULL,
  `commission` decimal(10,5) DEFAULT NULL,
  `profit` decimal(10,5) DEFAULT NULL,
  `swaps` decimal(10,5) DEFAULT NULL,
  `comment` varchar(25) NOT NULL DEFAULT '',
  `magic_number` int(11) NOT NULL DEFAULT 0,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,  
  PRIMARY KEY (`master_id`,`trade_id`),
  CONSTRAINT `{table}_master_id_fkey` FOREIGN KEY (`master_id`) REFERENCES `{database}`.`{table_masters}` (`master_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;""".format(database=database, table=tables_names['trades_master'], table_masters=tables_names['terminals_master'])
    
    #---

    tables_queries['trades_slave'] = """CREATE TABLE IF NOT EXISTS `{database}`.`{table}` (
  `master_id` varchar(25) NOT NULL,
  `instrument` varchar(12) NOT NULL,
  `direction` int(11) NOT NULL,
  `volume` decimal(10,5) NOT NULL,
  `open_price` decimal(10,5) NOT NULL,
  `open_time` timestamp NOT NULL DEFAULT 0,
  `close_time` timestamp NOT NULL DEFAULT 0,
  `close_price` decimal(10,5) DEFAULT NULL,
  `master_trade_id` varchar(25) NOT NULL,
  `stop_loss` decimal(10,5) DEFAULT NULL,
  `take_profit` decimal(10,5) DEFAULT NULL,
  `slave_id` varchar(25) NOT NULL,
  `slave_trade_id` varchar(25) NOT NULL,
  `commission` decimal(10,5) DEFAULT NULL,
  `profit` decimal(10,5) DEFAULT NULL,
  `swaps` decimal(10,5) DEFAULT NULL,
  `comment` varchar(25) NOT NULL DEFAULT '',
  `magic_number` int(11) NOT NULL DEFAULT 0,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,  
  `status` text,
  PRIMARY KEY (`slave_id`,`slave_trade_id`),
  KEY `{table}_master_id_fkey1` (`master_id`,`master_trade_id`),
  CONSTRAINT `{table}_master_id_fkey` FOREIGN KEY (`master_id`) REFERENCES `{database}`.`{table_masters}` (`master_id`),
  CONSTRAINT `{table}_master_id_fkey1` FOREIGN KEY (`master_id`, `master_trade_id`) REFERENCES `{database}`.`{table_trades_master}` (`master_id`, `trade_id`),
  CONSTRAINT `{table}_slave_id_fkey` FOREIGN KEY (`slave_id`) REFERENCES `{database}`.`{table_slaves}` (`slave_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;""".format(database=database,
        table=tables_names['trades_slave'],
        table_trades_master=tables_names['trades_master'],
        table_masters=tables_names['terminals_master'],
        table_slaves=tables_names['terminals_slave'])

    #---
    
    #logging.info("First insert into tables")
    #query = "INSERT IGNORE INTO " + g_tableName_masters + " VALUES ('" + g_master_id_setting + "', '" + g_deposit_currency + "');"; # + comment

    #---
    
    cursor = conn.cursor()

    for (name, query) in tables_queries.items():
        #print(name , query)

        try:
            logging.info(" "*2 + "Creating table '{}': ".format(name))
            logging.info(" "*4 + name.rjust(14) + ": " + tables_queries[name])
            cursor.execute(query)
        except mysql.connector.Error as err:
            logging.error(query)
            logging.error(err.msg)
    
def tables_drop_or_truncate(conn, database, tables_prefix, tables_names, action):
    logging.info("{action} tables".format(action=action))
    tables_queries = OrderedDict()

    tables_queries['terminals_master'] = "{action} TABLE `{database}`.`{table}`;".format(
        action=action, database=database, table=tables_names['terminals_master'])

    tables_queries['terminals_slave'] = "{action} TABLE `{database}`.`{table}`;".format(
        action=action, database=database, table=tables_names['terminals_slave'])

    tables_queries['trades_master'] = "{action} TABLE `{database}`.`{table}`;".format(
        action=action, database=database, table=tables_names['trades_master'])
        
    tables_queries['trades_slave'] = "{action} TABLE `{database}`.`{table}`;".format(
        action=action, database=database, table=tables_names['trades_slave'])
        
    cursor = conn.cursor()

    for (name, query) in tables_queries.items()[::-1]:
        #print(name , query)

        try:
            logging.info(" "*2 + "Droping table '{}': ".format(name))
            logging.info(" "*4 + name.rjust(14) + ": " + tables_queries['trades_slave'])
            cursor.execute(query)
        except mysql.connector.Error as err:
            logging.error(query)
            logging.error(err.msg)
    
def tables_truncate(conn, database, tables_prefix, tables_names):
    return tables_drop_or_truncate(conn, database, tables_prefix, tables_names, 'TRUNCATE')

def tables_drop(conn, database, tables_prefix, tables_names):
    return tables_drop_or_truncate(conn, database, tables_prefix, tables_names, 'DROP')

def get_tables_names(tables_prefix):
    tables_names = OrderedDict()
    tables_names['terminals_master'] = tables_prefix + "terminals_master"
    tables_names['terminals_slave'] = tables_prefix + "terminals_slave"
    tables_names['trades_master'] = tables_prefix + "trades_master"
    tables_names['trades_slave'] = tables_prefix + "trades_slave"
    return(tables_names)

