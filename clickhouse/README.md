ClickHouse Cluster
------------------

This folder contains simple configurations to be used in order to setup a ClickHouse cluster to be used from ntopng.

In this example we will use the following hosts
- zookeeper (192.168.2.221)
- clickhouse1 (192.168.2.92)
- clickhouse2 (192.168.2.93)

This setus defines one ClickHouse cluster name ntop_cluster with one shard and two replica on nodes clickhouse1 and clickhouse2.


Zookeeper Setup
---------------

On the zookeeper host do
- sudo apt-get install zookeeper
- sudo -u zookeeper /usr/share/zookeeper/bin/zkServer.sh start



ClickHouse Setup
----------------

On the clickhouse hosts do (as root)
- install clickhouse as speciied in https://clickhouse.com/docs/en/install/
- for host clickhouse1 copy files contained in directory clickhouse1, and  host clickhouse2 copy files contained in directory clickhouse2. Such files will be copied in /etc/clickhouse-server/config.d
- service clickhouse-server restart


ntopng
------

Start ntopng as
- ntopng -i XXX -F "clickhouse-cluster;192.168.2.92@9000,9004;ntopng;default;"