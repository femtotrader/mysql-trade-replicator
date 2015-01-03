MySQL Trade Replicator
======================

MySQL Trade Replicator enables you to copy trades between separate accounts, possibly located
at different brokerages. Trades are copied from "master" account to a number of "slave"
accounts, volume scaling and trade direction inversion are supported on slave side.

Trades are copied via database, so Trade Replicator scripts both master and slave
versions use mql4-mysql https://github.com/sergeylukin/mql4-mysql
to communicate with MySQL database server.

http://dev.mysql.com/downloads/

Why you might want to try this?
-------------------------------

* you are a successful trader and would like to offer signal providing service so
your clients could subscribe to your trading for a monthly fee and you do not
want to do this via Zulu or eToro for your own reasons;

* you are a very consistent Forex looser wishing to use trade inversion
in order to turn your loosing trades on one account into the winning trades
on another account.

Some remarks to the above proposals: in the first case your client base should be
rather small and you have to give each person a different DB user/password to make
it possible to terminate service access for a given client if need be.
For bigger client base it is hardly possible to manage all clients manually.

As for the second case, what I mean by consistent looser is that you have to loose
significantly more than 50% of the trades and loses should be definitely way bigger
than the spread and than your average win.
It turns out that consistent losers are as rare as the consistent winners, so it is more
of a joke but of course you are welcome to try that and see :)


Supported Platforms
-------------------
Windows 7+ and any version of MT4 terminal running on it (including build>=600).


Original work
-------------
This MySQL trade replicator is based on

[https://github.com/kr0st/trade_replicator/](https://github.com/kr0st/trade_replicator/)


License
-------
BSD 2-Clause (http://opensource.org/licenses/BSD-2-Clause).


Install
-------
Install MySQL free community edition from http://dev.mysql.com/downloads/

Set password for user "root" (123456 by example)

You should have a database called "test"

Master script is used at the signal provider side and slave version is used
at the signal subscriber side.

* Install - MT4 master and MT4 slave

Copy files from MQL4 directory into MT4 directory of master and slave

* Install - JForex master and MT4 slave

Copy files from JForex directory into your JForex directory `C:\Users\<User>\Documents\JForex\Strategies`
JForex master needs a database driver to work which you should obtain from MySQL site at https://dev.mysql.com/downloads/connector/j/
The file is called `mysql-connector-java-5.1.30-bin.jar`.
This file should be placed into "Documents\JForex\Strategies\files".
`JForexMySQLTradeReplicatorMaster.java` file must be placed in `Documents\JForex\Strategies`
When this is done just compile this java file from Dukascopy trading platform and start it.

Important Notes
---------------
If you opened some trades and then run the master script it will detect that some
new trades appeared and will write them to DB for further copying to slave accounts.
Your master account should be used only for trading that you want to be copied.

On start script will try to create all needed DB tables, so at least on the first start
you should give script’s DB user rights to create tables.

Many masters and slaves could use the same database as long as the rule of uniqueness
is not violated for master ids and for slave ids.

It is possible to copy from many masters at once in a single running slave script instance.

This project is still in alpha stage so be very careful because some issues could occur
and I will not be responsible of damage (particularly the loss of money).


How it works
------------
Each master is assigned a random-generated id, when master script is running each trade
that appears on master account will be placed in the database (trades_master table)
identified uniquely by master id and MT4 order ticket.

At client side slave version of the script is running and scanning DB every second
for new master trades and also for trades that have been closed by master.

If new master trade is found it is opened in client MT4 terminal and
is written to DB (trades_slave table) uniquely identified by slave id and
new order ticket. In case trade copy failed, status column will have the error number
that has been reported by the MT4 server. When there is no error status column is NULL.

When master closes the trade it is also going to be closed at the client side and
information in DB will be updated with the time and profit of the closed trade.

This is how it works in short, you are encouraged to view the database schema because
it contains a lot of useful information that can be used to prepare the summary
of trading for masters and slaves.


Quick Start MT4 master - MT4 slave
----------------------------------
Before running the scripts they have to be properly configured. You can do it every time
when you run the script or you can write values you need right into mq4 script file
and compile it.

The first important thing to understand and configure is master and slave ids.
The best way is to use some password generating software and generate 20-symbol ids
such as http://strongpasswordgenerator.com/
However it should be clear that slave script should contain the existing master id
because slave script will be copying trades only from the master with the given id.

When setting up a slave side script, please note that it can copy trades from many
masters therefore you can supply multiple space-separated masters ids
to the slave script, here is how to configure masters ids in a slave-side scrip:

#### Database settings

Open `MQL4/Include/mql4-mysql_config.mqh` and edit it

	extern string  g_db_host_setting     = "localhost"; //DB hostname ('localhost' or '127.0.0.1')
	extern string  g_db_user_setting     = "root"; //DB user ('root')
	extern string  g_db_pass_setting     = "123456"; //DB password ('123456')
	extern string  g_db_name_setting   = "test"; //DB name

	extern int     g_db_port_setting     = 3306; //DB port
	extern int     g_db_socket_setting   = 0; //DB socket
	extern int     g_db_client_setting   = 0; //DB client


#### Edit master expert advisor

Set `g_master_id_setting`

	extern string g_master_id_setting = "n9o816RTuaxJt99WSfD8";  //master_id

You can put an other value if you want.
At first startup you will also have to create database and register this new master.
It will create a new row in table terminals_master

	extern bool g_create_tables_setting = true; //create tables (set to True only first time to create database tables)
	extern bool g_register_master_setting = true; //register master to DB (set to True only first time you use a new master)

Compile master script and drag this EA on a chart.

#### Edit slave expert advisor

Set `g_slave_id_setting`

	extern string g_slave_id_setting = "fVB472V9x8i4RN081pg8"; //slave_id - a string of 20 symbols recommended id, use some passwords generator to obtain it http://strongpasswordgenerator.com/

You can put an other value if you want.

A slave EA need to subscribe to master so you need to set

	extern string g_subscribed_masters_setting = "n9o816RTuaxJt99WSfD8"; //subscribed_masters is a list of masters in the form "master1 master2 master3" etc. (blank space between each master)

If you want your slave subscribe to several slave just use a blank space between each master_id

At first startup of a new slave you have to register this new slave.

	extern bool g_register_slave_setting = true; //register slave to DB (set to True only first time you use a new slave)

Compile slave script and drag this EA on a chart.

#### Recompile the scripts.

When ids are configured it is time to setup the database access. Parameters are pretty
much self-explanatory, the only thing to remember here is that read/write access is
required both for master and slave scripts.

Please see other parameters in the script file, all of them are easy to understand and
all of them need to be configured properly.

#### Test on demo account

You should only use this software with demo account in order to test it.

Other features
--------------
* JForex master

You can send orders from JForex to MT4 (or any other slave) using JForex master

* Python master

You can send orders from a Python script to MT4 (or any other slave) using Python master

See example in Python directory

* Account analyst

A Python Pandas script is also given to compare trades from `trades_master`
and `trades_slave`

DB Schema
---------

![DB schema image](https://mysql-trade-replicator.googlecode.com/svn/trunk/_Models/trade_replicator.png)


ToDo
----
* JForex slave
* Support of modification of SL / TP
* Support of pending orders

Contact
-------

* Mail: femto dot trader at g mail dot com
* Twitter: [@FemtoTrader](https://twitter.com/FemtoTrader)
* Website: https://sites.google.com/site/femtotrader/
* Donate: https://sites.google.com/site/femtotrader/donate