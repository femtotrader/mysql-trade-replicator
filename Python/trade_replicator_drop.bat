@echo off
echo ARE YOU SURE YOU REALLY WANT TO DROP TABLES?
echo Close this window or press CTRL+C to CANCEL
echo Press ENTER to accept
pause
python trade_replicator_manage.py --host 127.0.0.1 --database test --user root --password 123456 --port 3306 --action drop
REM --tablesprefix
pause