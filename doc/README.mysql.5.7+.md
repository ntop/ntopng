### Authentication on MySQL 5.7+

In MySQL 5.7+ (e.g. on Ubuntu 16.04 and Ubuntu18.04) there is a new authentication schema
https://dev.mysql.com/doc/mysql-security-excerpt/5.7/en/socket-authentication-plugin.html
and authentication as in the previous database versions, will not work.

As a quick solution, you can restore the old authentication as follows.

Log into MySQL from the command line

```
$ mysql -uroot -hlocalhost
```

Make sure to specify `localhost`, specifying `127.0.0.1` might end up in an `ERROR 1698 (28000): Access denied for user 'root'@'localhost'`.

Then, set `mysql_native_password` as authentication plugin:

```
mysql> update mysql.user set plugin="mysql_native_password";
Query OK, 1 row affected (0,00 sec)
Rows matched: 3  Changed: 1  Warnings: 0
mysql> flush privileges;
Query OK, 0 rows affected (0,01 sec)
mysql> ^DBye
```

Authentication plugin `mysql_native_password` can be set also for a single user (or for a subset of them) by adding a `WHERE` clause to the query above

```
mysql> update mysql.user set plugin="mysql_native_password" WHERE user='root';
Query OK, 0 rows affected (0,00 sec)
Rows matched: 1  Changed: 0  Warnings: 0
```
