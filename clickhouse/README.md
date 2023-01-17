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


Third Party Resources
---------------------

There are several documents on the Internet about ClickHouse setup. As clickhouse has changes several tiny configuration details as new versions are released, please make sure you adapt these files to the latest clickhouse version. A typical change is to replace `<yandex>..</yandex>` with `<clickhouse>...</clickhouse>`
- https://hakanmazi123.medium.com/step-by-step-clickhouse-cluster-installation-with-3-servers-12cfa21daa1a
- https://altinity.com/blog/how-to-set-up-a-clickhouse-cluster-with-zookeeper
- https://kb.altinity.com/altinity-kb-setup-and-maintenance/altinity-kb-zookeeper/clickhouse-keeper/
- https://clickhouse.com/docs/en/guides/sre/keeper/clickhouse-keeper/
- 
