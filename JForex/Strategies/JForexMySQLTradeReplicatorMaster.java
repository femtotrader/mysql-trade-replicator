/*
 * JForexMySQLTradeReplicatorMaster.java
 * Trades replicator using MySQL database
 * JForex master
 * 
 * Copyright © 2014, FemtoTrader
 * https://sites.google.com/site/femtotrader/
 * 
 * Distributed under the BSD license
 * http://opensource.org/licenses/BSD-2-Clause
 * 
 * Inspired from trade_replicator
 * https://github.com/kr0st/trade_replicator
 * 
 * Dependencies:
 *  mysql-connector-java-5.1.30-bin.jar
 */
 
package jforex;

import java.util.*;

import com.dukascopy.api.*;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.ResultSet;
import java.text.SimpleDateFormat;
import java.sql.ResultSetMetaData;

@Library("mysql-connector-java-5.1.30-bin.jar")

@RequiresFullAccess
public class JForexMySQLTradeReplicatorMaster implements IStrategy {

    public class DB_Trade
    {
        public class General_Exception extends Exception
        {
            private String description;
            public General_Exception(String s)
            {
                description = s;
            }

            public String toString()
            {
                return description;
            }
        }
        
        public String master_id;
        public String instrument;
        public int direction;
        public double volume;
        public double open_price;
        public Date open_time;
        public Date close_time;
        public double close_price;
        public String trade_id;
        public double stop_loss;
        public double take_profit;
        public double commission;
        public double profit;
        public double swaps;
        public String comment;
        public int magic_number;
        //public Date created;
        //public Date updated;
        
        public DB_Trade(ResultSet rs) throws SQLException, General_Exception
        {
            ResultSetMetaData meta = rs.getMetaData();
            int cols = meta.getColumnCount();
            if (cols != 18)
                throw new General_Exception("Unexpected number of columns in master trades table, check your DB schema.");
            
            master_id = rs.getString(1);
            instrument = rs.getString(2);
            direction = rs.getInt(3);
            volume = rs.getDouble(4);
            open_price = rs.getDouble(5);
            open_time = rs.getDate(6);
            try {
                close_time = rs.getDate(7);
            } catch (Exception e) {
                close_time = null;
            }

            close_price = rs.getDouble(8);
            trade_id = rs.getString(9);
            stop_loss = rs.getDouble(10);
            take_profit = rs.getDouble(11);
            commission = rs.getDouble(12);
            profit = rs.getDouble(13);
            swaps = rs.getDouble(14);
            comment = rs.getString(15);
            magic_number = rs.getInt(16);
            //created = 
            //updated = 
        }
        
        public String toString()
        {
            String res = "";
            
            SimpleDateFormat date = new SimpleDateFormat("yyyy-MM-DD hh:mm:ss.SSSZ");
            
            try
            {
                if (open_time == null)
                    open_time = date.parse("1970-01-01 00:00:00.000+0000");
                    
                if (close_time == null)
                    close_time = date.parse("1970-01-01 00:00:00.000+0000");
            }
            catch (Exception e)
            {
                console.getOut().println("ERROR:" + e.toString());
                return "";
            }

            res = "master_id=" + master_id + " instrument=" + instrument + " direction=" + direction + " volume=" + volume +
                  " open_price=" + open_price + " open_time=" + date.format(open_time) + " close_time=" + date.format(close_time) + " close_price=" + close_price +
                  " trade_id=" + trade_id + " stop_loss=" + stop_loss + " take_profit=" + take_profit + " commission=" + commission + " profit=" + profit + " swaps=" + swaps;

            return res;
        }
    }
    
    @Configurable("DB IP/host")
    public String db_ip_setting = "127.0.0.1";
    @Configurable("DB port")
    public String db_port_setting = "3306";
    @Configurable("DB login")
    public String db_user_setting = "root";
    @Configurable("DB password")
    public String db_password_setting = "123456";
    @Configurable("DB name")
    public String db_name_setting = "test";
    @Configurable("DB table prefix")
    public String db_table_prefix_setting = "trade_replicator_";
    @Configurable("Master ID")
    public String master_id_setting = "n9o816RTuaxJt99WSfD8"; //20 symbols recommended id, use some passwords generator to obtain it
    @Configurable("Deposit currency")
    public String deposit_currency_setting = "USD";
    @Configurable("Master comment")
    public String master_comment_setting = "master01";
    @Configurable("Drop tables")
    public boolean drop_tables = false;
    @Configurable("Create tables")
    public boolean create_tables = false;
    @Configurable("Register master")
    public boolean register_master = false;
    
    
    private IEngine engine;
    private IConsole console;
    private IHistory history;
    private IContext context;
    private IIndicators indicators;
    private IUserInterface userInterface;
    
    private Connection db_conn = null;
    
    private String g_table_name_terminals_master;
    private String g_table_name_terminals_slave;
    private String g_table_name_trades_master;
    private String g_table_name_trades_slave;
    
    private long prev_time_;

    private void init_table_names(String tableprefix) {
        g_table_name_terminals_master = tableprefix + "terminals_master";
        g_table_name_terminals_slave = tableprefix + "terminals_slave";
        g_table_name_trades_master = tableprefix + "trades_master";
        g_table_name_trades_slave = tableprefix + "trades_slave";
    }

    private Connection db_connect(String db_name, String host, String port, String user, String pass)
    {
        Connection connection = null;
        try
        {
            //Class.forName("com.mysql.jdbc.Driver").newInstance();
            String url = "jdbc:mysql://" + host + ":" + port + "/" + db_name;
            console.getOut().println(url);
            connection = DriverManager.getConnection(url, user, pass);
        }
        catch (SQLException e)
        {
            console.getOut().println("DB connection failed!!!");
            return null;
        }
        
        if (connection != null)
        {
            console.getOut().println("DB connection established");
        }
        else
        {
            console.getOut().println("Failed to make a connection!!!");
        }
        
        return connection;
    }
        
    public String InstrumentToString(Instrument instrument) {
        String s = instrument.toString();
        s = s.replace("/", "");
        s = s.replace("\\", "");
        return(s);
    }
    
    public String quote(String s) {
        return("'" + s + "'");
    }

    public String backquote(String s) {
        return("`" + s + "`");
    }

    void drop_table_replicator(String db_name, String tablePrefix) {
        action_table_replicator(db_name, tablePrefix, "DROP");
    }

    void truncate_table_replicator(String db_name, String tablePrefix) {
        action_table_replicator(db_name, tablePrefix, "TRUNCATE");
    }

    void action_table_replicator(String db_name, String tablePrefix, String action)
    {
        String query;
    
        ArrayList<String> a_tablename = new ArrayList<String>();
        
        a_tablename.add(g_table_name_trades_slave);
        a_tablename.add(g_table_name_trades_master);
        a_tablename.add(g_table_name_terminals_slave);
        a_tablename.add(g_table_name_terminals_master);

        Statement statement;

        for (String tablename : a_tablename)
        {
            try {
                statement = db_conn.createStatement();
                query = action + " TABLE " + backquote(db_name) + "." + backquote(tablename) + ";";
                console.getOut().println(query);
                statement.execute(query);
            } catch (SQLException e) {
                console.getOut().println("ERROR: " + e.toString());
            }
        }    
    }

    boolean create_table_replicator(String db_name, String tablePrefix)
    {
        boolean b_result;
        String query;
        Statement statement;
    
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
        try {
            statement = db_conn.createStatement();
            console.getOut().println(query);
            b_result = statement.execute(query);
        } catch (SQLException e) {
            console.getOut().println("ERROR: " + e.toString());
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
        try {
            statement = db_conn.createStatement();
            console.getOut().println(query);
            b_result = statement.execute(query);
        } catch (SQLException e) {
            console.getOut().println("ERROR: " + e.toString());
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
        try {
            statement = db_conn.createStatement();
            console.getOut().println(query);
            b_result = statement.execute(query);
        } catch (SQLException e) {
            console.getOut().println("ERROR: " + e.toString());
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
        try {
            statement = db_conn.createStatement();
            console.getOut().println(query);
            b_result = statement.execute(query);
        } catch (SQLException e) {
            console.getOut().println("ERROR: " + e.toString());
        }

        //---
    
        return(true);
    }
                                    
    public boolean register(String table_name, String terminal_type, String terminal_id, String deposit_currency, String comment) {
        try {
            Statement statement = db_conn.createStatement();
            String sep = ", ";
            String query = "INSERT INTO " + table_name + "(" + terminal_type + "_id, deposit_currency, comment, created, updated) VALUES (" + quote(master_id_setting) + sep + quote(deposit_currency_setting)
                + sep + quote(master_comment_setting) + sep + "NULL" + sep + "NULL" + ") ON DUPLICATE KEY UPDATE comment=VALUES(comment), deposit_currency=VALUES(deposit_currency), updated=VALUES(updated);";
            console.getOut().println(query);
            return(statement.execute(query));
        } catch (SQLException e) {
            console.getOut().println("ERROR: " + e.toString());
            return(false);
        }

    }
 
    public boolean register_master(String table_name, String terminal_id, String deposit_currency, String comment) {
        return(register(table_name, "master", terminal_id, deposit_currency, comment));
    }
    
    
    public void onStart(IContext context) throws JFException {
        this.engine = context.getEngine();
        this.console = context.getConsole();
        this.history = context.getHistory();
        this.context = context;
        this.indicators = context.getIndicators();
        this.userInterface = context.getUserInterface();
        
        db_conn = db_connect(db_name_setting, db_ip_setting, db_port_setting, db_user_setting, db_password_setting);

        init_table_names(db_table_prefix_setting);

        if (drop_tables) {
            try {
                drop_table_replicator(db_name_setting, db_table_prefix_setting);
            } catch (Exception e) {
                console.getOut().println("Can't drop tables");      
            }
        }
        
        if (create_tables) {
            try {
                create_table_replicator(db_name_setting, db_table_prefix_setting);
            } catch (Exception e) {
                console.getOut().println("Can't drop tables");      
            }
        }

        if (register_master) {
            try {
                register_master(g_table_name_terminals_master, master_id_setting, deposit_currency_setting, master_comment_setting);
            } catch (Exception e) {
                console.getOut().println("Can't register master to trade replicator (this master_id maybe ever exists)");      
            }
        }
        
        prev_time_ = 0;

    }

    public void onAccount(IAccount account) throws JFException {
    }

    public void onMessage(IMessage message) throws JFException {
    }

    public void onStop() throws JFException
    {
        try
        {
            if (db_conn != null) {
                db_conn.close();
                console.getOut().println("DB connection closed");
            }
        }
        catch (SQLException e)
        {
            console.getOut().println("DB connection failed to close!!!");
            return;
        }
    }

    private void onTime(long time) throws JFException
    {
        //console.getOut().println("--> onTime");
        try
        {
            ArrayList<DB_Trade> trades;
            
            trades = get_open_trades_from_db();
            find_closed_trades(trades);
            
            trades = get_open_trades_from_db();
            find_new_trades(trades);
        }
        catch (Exception e)
        {
            console.getOut().println(e);
            return;
        }
        //console.getOut().println("<-- onTime");
    }

    public void onTick(Instrument instrument, ITick tick) throws JFException {
        //console.getOut().println("new tick " + InstrumentToString(instrument));
        long cur_time = tick.getTime();
        if (cur_time - prev_time_ >= 1000)
        {
            prev_time_ = cur_time;
            onTime(cur_time);
        }    
    }
    
    public void onBar(Instrument instrument, Period period, IBar askBar, IBar bidBar) throws JFException {
    }
    
    
    private ArrayList<DB_Trade> get_open_trades_from_db()
    {
        //console.getOut().println("--> get_open_trades_from_db");
        ArrayList<DB_Trade> open_trades = new ArrayList<DB_Trade>();

        try
        {
            Statement query = db_conn.createStatement(ResultSet.TYPE_SCROLL_INSENSITIVE, ResultSet.CONCUR_READ_ONLY);
            ResultSet rs = query.executeQuery("SELECT * FROM " + g_table_name_trades_master + " WHERE close_time=0 AND master_id = " + quote(master_id_setting) + ";");
            
            //print_result_set(rs);
            
            rs.last();
            int rows = rs.getRow();
            rs.beforeFirst();
            
            for (int i = 0; i < rows; ++i)
            {
                rs.next();            
                DB_Trade open_trade = new DB_Trade(rs);
                open_trades.add(open_trade);
                
                //console.getOut().println("trade#" + i + " = " + open_trade);
            }
        }
        catch (SQLException e)
        {
            console.getOut().println("ERROR: " + e.toString());
            return open_trades;
        }
        catch (DB_Trade.General_Exception e)
        {
            console.getOut().println("ERROR: " + e.toString());
            return open_trades;
        }

        //console.getOut().println("<-- get_open_trades_from_db");
        return open_trades;
    }

    private IOrder is_trade_closed(String id) throws JFException
    {
        //console.getOut().println("--> is_trade_closed");
        
        IOrder order = history.getHistoricalOrderById(id);
        if (order != null)
        {
            if (order.getClosePrice() != 0)
            {
                //console.getOut().println("pos.id =  " + order.getId() + "close_time = " + order.getCloseTime() + " close_price = " + order.getClosePrice());
                //console.getOut().println("<-- is_trade_closed result non-null");
                return order;
            }
        }

        //console.getOut().println("<-- is_trade_closed result null");
        return null;
    }

    private void on_trade_close(IOrder closed_order) throws JFException
    {
        //console.getOut().println("--> on_trade_close");
        if (closed_order == null)
            return;

        String master_id = master_id_setting;
        double close_price = closed_order.getClosePrice();
        SimpleDateFormat date_format = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss.SSS"); //new SimpleDateFormat("yyyy-MM-dd hh:mm:ss.SSSZ");
        Date current = new Date();
        String close_time = date_format.format(current);
        String trade_id = closed_order.getId();
        double stop_loss = closed_order.getStopLossPrice();
        double take_profit = closed_order.getTakeProfitPrice();
        double profit = closed_order.getProfitLossInAccountCurrency();
        double swaps = 0;

        String query = "UPDATE " + g_table_name_trades_master + " SET stop_loss=" + stop_loss + ", take_profit=" + take_profit + ", close_time='" + close_time + "', close_price=" + close_price + ", profit=" + profit + ", swaps=" + swaps + " WHERE (master_id='" + master_id + "') AND (trade_id='" + trade_id + "');";
        console.getOut().println("Master closed trade: " + query);

        try
        {
            Statement statement = db_conn.createStatement();
            statement.execute(query);        
        }
        catch (SQLException e)
        {
            console.getOut().println("ERROR: " + e.toString());
            return;
        }
        
        //console.getOut().println("<-- on_trade_close");
    }
        
    private void find_closed_trades(ArrayList<DB_Trade> trades) throws JFException
    {
        //console.getOut().println("--> find_closed_trades");
        for (DB_Trade trade : trades)
        {
            on_trade_close(is_trade_closed(trade.trade_id));
        }
        //console.getOut().println("<-- find_closed_trades");
    }
            
    private void on_new_trade(IOrder order)
    {
        //console.getOut().println("--> on_new_trade");
        String master_id = master_id_setting;
        String instrument = order.getInstrument().toString();
        instrument = instrument.replace("/", "");
        instrument = instrument.replace("\\", "");
        
        int direction = 0;
        if (!order.isLong()) direction = 1; // ToFix: pending orders

        double volume = order.getAmount() * 10; //convert into mt4 lots (from fractions of million to fractions of 100K)
        double open_price = order.getOpenPrice();
        
        //SimpleDateFormat date_format = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss.SSSZ");
        SimpleDateFormat date_format = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss.SSS");
        Date current = new Date();
        String open_time = date_format.format(current);
        String close_time = "0000-00-00 00:00:00.000";
        String trade_id = order.getId();
        double stop_loss = order.getStopLossPrice();
        double take_profit = order.getTakeProfitPrice();
        
        double com = order.getCommission();
        String comment = order.getLabel(); //"order sent with JForex";
        int magic_number = 0;
        String commission = "" + com;
        String label = order.getLabel();
        
        String sep = ", ";
        String query = "INSERT INTO " + g_table_name_trades_master + " VALUES (" + quote(master_id) + sep
            + quote(instrument) + sep + direction + sep + volume + sep
            + open_price + sep + quote(open_time) + sep + quote(close_time) + sep + "NULL" + sep
            + quote(trade_id) + sep + stop_loss + sep
            + take_profit + sep + commission + sep + "NULL" + sep
            + "NULL" + sep + quote(comment) + sep + magic_number + sep + "NULL" + sep + "NULL" + ");";
        
        console.getOut().println("Master opened a new trade: " + query);
        
        try
        {
            Statement statement = db_conn.createStatement();
            statement.execute(query);        
        }
        catch (SQLException e)
        {
            console.getOut().println("ERROR: " + e.toString());
            return;
        }
        
        //console.getOut().println("<-- on_new_trade");
    }    
    private void find_new_trades(ArrayList<DB_Trade> trades) throws JFException
    {
        //console.getOut().println("--> find_new_trades");
        List<IOrder> orders = engine.getOrders();
        for (IOrder order : orders)
        {
            if (order.getState() != IOrder.State.FILLED)
                continue;

            Boolean found = false;
            for (DB_Trade trade : trades)
            {
                String pos_id = order.getId();
                pos_id.trim();
                trade.trade_id.trim();

                //console.getOut().println("trade_id = " + trade.trade_id + ", pos id = " + pos_id);
                if (trade.trade_id.equals(pos_id))
                {
                    found = true;
                    break;
                }
            }

            if (!found)
                on_new_trade(order);
        }
        
        //console.getOut().println("<-- find_new_trades");
    }
}