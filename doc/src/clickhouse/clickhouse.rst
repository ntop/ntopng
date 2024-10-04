Connect to ClickHouse
--------------------

ntopng connect sto clickhouse using two different connections:

- Flows are imported into the database in batch mode using clickhouse-client. This is because in columnary databases this is the most efficient technique for importing large volumes of data.
- MySQL connection to insert alerts (theoretically this is not a large capacity actovoty so avoiding batch inserts reduces latency) and perform queries.


In order to connect ntopng to ClickHouse use option :code:`-F`. The format of this option is the following

.. code:: bash

    clickhouse;<host[@mysqlport]|unix-socket;<dbname>;<user>;<pw>

or 

.. code:: bash
	  
    clickhouse-cluster;<host[@mysqlport]|socket>;<dbname>;<user>;<pw>;<cluster name>

Where

- :code:`<host[@mysqlport]|socket>` Specifies the database :code:`host` or a :code:`socket` file. By default, port :code:`9000` is used for the connection via clickhouse-client and :code:`9004` for ClickHouse connection over MySQL. To use a different port, specify it with :code:`@mysqlport`. The host can be a symbolic name or an IP address. By default ntopng connects in clear text, this unless you want to do it over TLS and in this case you need to append a 's' after the port. Example :code:`192.168.2.1@9004s`. Please see later in this pare more information about TLS connections.
- :code:`<dbname>` Specifies the name of the database to be used and defaults to :code:`ntopng`
- :code:`<user>` Specifies an user with read and write permissions on :code:`<dbname>`
- :code:`<pw>` Specifies the password that authenticates :code:`<user>`
- :code:`<cluster name>` Specifies the name of the ClickHouse cluster :code:`<user>`

If you use a stand-alone ClickHouse database you need to use :code:`-F clickhouse;....` whereas with a cluster you need to use :code:`-F clickhouse-cluster;....`
  
Example
=======

To connect ntopng and ClickHouse, both running on the same machine, the following line can be used

.. code:: bash

    ./ntopng -F="clickhouse;127.0.0.1;ntopng;default;default"

In the example above, `127.0.0.1` is used to connect using IPv4 (using the symbolic string :code:`localhost` could resolve to an IPv6 address). A user :code:`default`, identified with password :code:`default`, with read and write permissions on database :code:`ntopng` is indicated as well. As shortcut you can use :code:`-F clickhouse` for :code:`F="clickhouse;127.0.0.1;ntopng;default;default"`

The above example with a ClickHouse cluster would be:

.. code:: bash

    ./ntopng -F="clickhouse-cluster;127.0.0.1;ntopng;default;default;ntop_cluster"



What's Stored in ClickHouse
---------------------------

ntopng stores both historical flows and alerts in ClickHouse.

IPv4 and IPv6 flows are stored in table :code:`flows`. A column :code:`INTERFACE_ID` is used to identify the interface on which the flow was seen, this is useful ntopng is monitoring multiple interfaces (see :code:`-i`).

Alerts are stored in several tables, all ending with suffix :code:`_alerts`. The table prefix indicates the alert family, e.g. :code:`host_alerts` table contains alerts for hosts, :code:`flow_alerts` table contains alerts for flows, and so on.

For more information, check the `ntopng database schema <https://github.com/ntop/ntopng/blob/dev/httpdocs/misc/db_schema_clickhouse.sql>`_.

TLS Connection
--------------

In order to connect ntopng with ClickHouse using a secure TCP connection, first, create the server certificate with the following command:

.. code:: bash 

    openssl req -subj "/CN=localhost" -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout /etc/clickhouse-server/server.key -out /etc/clickhouse-server/server.crt

This command generates a server certificate for secure communication between ntopng and ClickHouse, establishing a secure TCP connection.

.. note::
    
    To enable the ClickHouse user to use the `server.crt` and `server.key` files, it is necessary to change their owner. 
    Run the following command as a superuser to grant the required permissions:
    
.. code:: bash 

    chown clickhouse:clickhouse /etc/clickhouse-server/server.key /etc/clickhouse-server/server.crt

Open the ClickHouse config.xml file and uncomment the following lines:

- :code:`<!--<tcp_port_secure>9440</tcp_port_secure>-->`
- :code:`<!--<certificateFile>/etc/clickhouse-server/server.crt</certificateFile>-->`
- :code:`<!--<privateKeyFile>/etc/clickhouse-server/server.key</privateKeyFile>-->`

Restart ClickHouse.

Start ntopng using the `-F` option, but in this case, it is mandatory to indicate the database port with an `s` at the end of it.

.. code:: bash

    clickhouse;<host[@<port>s]>;<dbname>;<user>;<pw>

For example: 

.. code:: bash 

    ./ntopng -F="clickhouse;127.0.0.1@9440s;ntopng;default;default`

Securing the Connection in ClickHouse Cloud
===========================================

To secure the connection in ClickHouse Cloud, instead, the only thing to configure is adding the `s` character in the `-F` option after the ports list, when starting ntopng (or in the configuration file),
without needing to configure anything else.
For example:

.. code:: bash 

    ./ntopng -F="clickhouse-cloud;127.0.0.1@9440,3306s;ntopng;default,default;default`

.. note::

   Securing the connection when using ClickHouse Cloud is highly recommended,
   moreover ClickHouse Cloud by default only accepts secured connections

ClickHouse Is Eating All My Disk/Memory !
-----------------------------------------

The defaut ClickHouse package configuration is not optimizes for reducing disk and memory usage. In order to avoid this problem please `refer to this guide <https://github.com/ntop/ntopng/blob/dev/doc/README.clickhouse.md>`_ that explain in detail how to optimize the fatabase configuration.
