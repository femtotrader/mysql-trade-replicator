#!/usr/bin/env python
# -*- coding: utf-8 -*-

about = """
Python script to send order (master) via trade_replicator MySQL database

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

import argparse
import logging
import traceback
from trade_replicator_toolbox import *

import datetime
import os, random, string
import time

def random_alphanumeric_id(length):
    chars = string.ascii_letters + string.digits # + '!@#$%^&*()'
    random.seed = (os.urandom(1024))
    return(''.join(random.choice(chars) for i in range(length)))

def random_numeric_id(length):
    return(random.randint(10**8, 10**9))

def quote(s):
    return("'" + s + "'")

def create_db_timestamp(dt):
    if dt is not None and dt!=0:
        return(dt.strftime("%Y-%m-%d %H:%M:%S"))
    else:
        return("0000-00-00 00:00:00")

def execute_query(conn, query):       
    cursor = conn.cursor()
    try:
        logging.info("send query to DB")
        logging.info(query)
        cursor.execute(query)
        conn.commit()
        logging.info("DONE")
        return(True)
        
    except mysql.connector.Error as err:
        logging.error(err.msg)
        return(False)

def register_terminal(conn, table_name, terminal_type, terminal_id, deposit_currency, comment):
    query = "INSERT INTO %s (%s_id, deposit_currency, comment, created, updated) VALUES ('%s', '%s', '%s', NULL, NULL) ON DUPLICATE KEY UPDATE comment=VALUES(comment), deposit_currency=VALUES(deposit_currency), updated=VALUES(updated);" %  (table_name, 'master', terminal_id, deposit_currency, comment)
    return(execute_query(conn, query))
    
def register_terminal_master(conn, tables_names, master_id, deposit_currency, comment):
    return(register_terminal(conn, tables_names['terminals_master'], 'master', master_id, deposit_currency, comment))

def create_db_double(x):
    if x is None:
        return("NULL")
    else:
        return(str(x))

def send_trades_master_query(conn, tables_names, master_id, instrument, direction, volume, open_price, open_time,
            close_time, close_price, trade_id, stop_loss, take_profit,
            commission, profit, swaps, comment, magic_number):
    
    
    values = ", ".join([quote(master_id), quote(instrument), str(direction), str(volume), create_db_double(open_price), quote(create_db_timestamp(open_time)), quote(create_db_timestamp(close_time)), create_db_double(close_price), quote(trade_id), str(stop_loss), str(take_profit), str(commission), create_db_double(profit), create_db_double(swaps), quote(comment), str(magic_number),
    "NULL", "NULL"])
    query = "INSERT INTO %s VALUES (%s);" % (tables_names['trades_master'], values)
    execute_query(conn, query)
    return(trade_id)

def order_send(conn, tables_names, master_id, instrument, direction, volume, price,
            stop_loss=0.0, take_profit=0.0, comment="", magic_number=0):
    
    direction = direction.index
    open_price = price
    open_time = datetime.datetime.utcnow()
    close_time = 0
    close_price = None
    trade_id = random_alphanumeric_id(25)
    commission = 0.0
    profit = None
    swaps = None
    
    result = send_trades_master_query(conn, tables_names, master_id, instrument, direction, volume, open_price, open_time,
            close_time, close_price, trade_id, stop_loss, take_profit,
            commission, profit, swaps, comment, magic_number)
            
    return(result)

def order_modify():
    raise(NotImplementedError)

def order_close(conn, tables_names, master_id, trade_id):
    close_time = datetime.datetime.utcnow()
    query = "UPDATE %s SET close_time=%s, close_price=0 WHERE master_id=%s AND trade_id=%s" % (tables_names['trades_master'], quote(create_db_timestamp(close_time)), quote(master_id), quote(trade_id))
    execute_query(conn, query)
    return(True)
    
    # ToDo: partial close

def main(args):
    database = args.database
    tables_prefix = args.tablesprefix
    tables_names = get_tables_names(tables_prefix)
    master_id = args.masterid
    conn = get_db_conn(args)
    deposit_currency = args.deposit_currency
    comment = args.comment
    register_terminal_master(conn, tables_names, master_id, deposit_currency, comment)
    
    logging.info("open order")
    ticket = order_send(conn, tables_names, master_id, "EURUSD", ORDER_TYPE.SELL, 0.01, 1.34, 0.0, 0.0, "order send with python", 42)    
    logging.info("trade open as #%s" % ticket)
    
    delay = 5
    logging.info("waiting %d s" % delay)
    time.sleep(delay)
    
    logging.info("close order")
    b_result = order_close(conn, tables_names, master_id, ticket)
    
    conn.close()
    

    
if __name__ == '__main__':
    logger = logging.getLogger()
    logging.basicConfig(level = logging.DEBUG, format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    # File handler
    fh = logging.FileHandler('log_py_master.log')
    fh.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--dbengine", help="DB engine", action='store', default='mysql')
    parser.add_argument("--host", help="DB hostname", action='store', default='127.0.0.1')
    parser.add_argument("--database", help="DB name", action='store', default='test')
    parser.add_argument("--user", help="DB username", action='store', default='root')
    parser.add_argument("--password", help="DB user password", action='store', default='123456')
    parser.add_argument("--port", help="DB port", action='store', default='3306')
    parser.add_argument("--tablesprefix", help="tables prefix", action='store', default='trade_replicator_')
    parser.add_argument("--masterid", help="masterid", action='store', default='n9o816RTuaxJt99WSfD8')
    parser.add_argument("--deposit_currency", help="deposit_currency prefix", action='store', default='USD')
    parser.add_argument("--comment", help="comment (terminal master)", action='store', default='master01')
    parser.add_argument("--about", help="about", action='store_true')
    args = parser.parse_args()
   
    if args.about:
        print(about)
    else:
        main(args)
