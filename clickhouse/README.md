ClickHouse Cluster
------------------

This folder contains simple configurations to be used in order to setup a ClickHouse cluster to be used from ntopng.

In this example we will use the following hosts
- clickhouse1 (192.168.2.92)
- clickhouse2 (192.168.2.93)

This setus defines one ClickHouse cluster name ntop_cluster with one shard and two replica on nodes clickhouse1 and clickhouse2.



ClickHouse Setup
----------------

On the clickhouse hosts do (as root)
- install clickhouse as specified in https://clickhouse.com/docs/en/install/
- service clickhouse-server stop
- for host clickhouse1 copy files contained in directory clickhouse1, and  host clickhouse2 copy files contained in directory clickhouse2. Such files will be copied in /etc/clickhouse-server/config.d
- service clickhouse-server start


ntopng
------

Start ntopng as
- ntopng -i XXX -F "clickhouse-cluster;192.168.2.92;ntopng;default;;ntop_cluster"


Troubleshooting
----------------

- if during table creation you experience this error, `Code: 122. DB::Exception: Received from localhost:9000. DB::Exception: There was an error on [192.168.2.93:9000]: Code: 122. DB::Exception: Table columns structure in ZooKeeper is different from local table structure.` the best is to drop the database and sync data across all nodes. You can do this with `DROP DATABASE ntopng ON CLUSTER ntop_cluster SYNC;`


Third Party Resources
---------------------

There are several documents on the Internet about ClickHouse setup. As clickhouse has changes several tiny configuration details as new versions are released, please make sure you adapt these files to the latest clickhouse version. A typical change is to replace `<yandex>..</yandex>` with `<clickhouse>...</clickhouse>`
- https://hakanmazi123.medium.com/step-by-step-clickhouse-cluster-installation-with-3-servers-12cfa21daa1a
- https://altinity.com/blog/how-to-set-up-a-clickhouse-cluster-with-zookeeper
- https://kb.altinity.com/altinity-kb-setup-and-maintenance/altinity-kb-zookeeper/clickhouse-keeper/
- https://clickhouse.com/docs/en/guides/sre/keeper/clickhouse-keeper/
