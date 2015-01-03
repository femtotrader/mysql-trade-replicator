#!/usr/bin/env python
# -*- coding: utf-8 -*-

about = """
Python script to manage trade_replicator MySQL database

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
import sys
from trade_replicator_toolbox import *

# mysql-connector-python-1.1.6-py2.7.msi

def manage(args):    
    database = args.database
    tables_prefix = args.tablesprefix
    tables_names = get_tables_names(tables_prefix)
    conn = get_db_conn(args)
    
    if args.action in ACTIONS_ALLOWED:
        logging.info("Run '%s'" % args.action)
        if args.action == 'analyst':
            tables_analyst(conn, tables_names, args)

        elif args.action == 'create':
            tables_create(conn, database, tables_prefix, tables_names)

        elif args.action == 'drop':
            tables_drop(conn, database, tables_prefix, tables_names)

        elif args.action == 'truncate':
            tables_truncate(conn, database, tables_prefix, tables_names)
        
        else:
            raise(NotImplementedError)
            
    else:
        raise(NotImplementedError)
    
    conn.close()    
    logging.info("database connection closed")

def cast_args_manage(args):
    args.port = int(args.port)
    args.action = args.action.lower()

    return(args)
    
if __name__ == '__main__':
    logger = logging.getLogger()
    #logger = logging.getLogger(__name__)
    
    logging.basicConfig(level=logging.DEBUG)

    # File handler
    fh = logging.FileHandler('trade_replicator_manage.log')
    fh.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    
    logging.info('Manage trade_replicator')
  
    parser = argparse.ArgumentParser()
    #parser.add_argument("--dbengine", help="DB engine", action='store', default='mysql')
    parser.add_argument("--host", help="DB hostname", action='store', default='127.0.0.1')
    parser.add_argument("--database", help="DB name", action='store', default='test')
    parser.add_argument("--user", help="DB username", action='store', default='root')
    parser.add_argument("--password", help="DB user password", action='store', default='123456')
    parser.add_argument("--port", help="DB port", action='store', default='3306')
    parser.add_argument("--tablesprefix", help="tables prefix", action='store', default='trade_replicator_')
    #parser.add_argument("--master_id", help="master_id", action='store', default='n9o816RTuaxJt99WSfD8')
    #parser.add_argument("--master_deposit_currency", help="master_id", action='store', default='USD')
    parser.add_argument("--masterid_algo", help="masterid1:algoA,masterid2:algoA,masterid3:algoB,masterid4:algoB", action='store', default='11:algo1,12:algo2')
    parser.add_argument("--slavetradesclosed", help="only closed slave trades", action='store_true')
    parser.add_argument("--slavetradesopened", help="only opened slave trades", action='store_true')
    parser.add_argument("--about", help="about", action='store_true')
    parser.add_argument("--action", help="action to do: " + "'" + "', '".join(ACTIONS_ALLOWED) + "'", action="store", default='analyst')
    args = parser.parse_args()
   
    args = cast_args_manage(args)
    args.dbengine = 'mysql'

    if args.about:
        print(about)
    else:
        manage(args)
