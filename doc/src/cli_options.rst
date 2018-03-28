.. _CliOptions:

Command Line Options
--------------------
ntopng supports a large number of command line parameters. To see what they are, simply enter the command ntopng -h and the help information should be printed

.. code:: bash

   ntopng --help
   Usage:
   ntopng <configuration file path>
   or
   ntopng <command line options>

   Options:
   [--dns-mode|-n] <mode>              | DNS address resolution mode
                                       | 0 - Decode DNS responses and resolve
                                       |     local numeric IPs only (default)
                                       | 1 - Decode DNS responses and resolve all
                                       |     numeric IPs
                                       | 2 - Decode DNS responses and don't
                                       |     resolve numeric IPs
                                       | 3 - Don't decode DNS responses and don't
                                       |     resolve numeric IPs
   [--interface|-i] <interface|pcap>   | Input interface name (numeric/symbolic),
                                       | view or pcap file path
   [--data-dir|-d] <path>              | Data directory (must be writable).
                                       | Default: /var/tmp/ntopng
   [--install-dir|-t] <path>           | Set the installation directory to <dir>.
                                       | Should be set when installing ntopng
                                       | under custom directories
   [--daemon|-e]                       | Daemonize ntopng
   [--httpdocs-dir|-1] <path>          | HTTP documents root directory.
                                       | Default: httpdocs
   [--scripts-dir|-2] <path>           | Scripts directory.
                                       | Default: scripts
   [--callbacks-dir|-3] <path>         | Callbacks directory.
                                       | Default: scripts/callbacks
   [--prefs-dir|-4] <path>             | Preferences directory used to serialize
                                       | and deserialize file
                                       | containing runtime preferences.
                                       | Default: /var/tmp/ntopng
   [--no-promisc|-u]                   | Don't set the interface in promisc mode.
   [--traffic-filtering|-k] <param>    | Filter traffic using cloud services.
                                       | (default: disabled). Available options:
                                       | httpbl:<api_key>   See README.httpbl
   [--http-port|-w] <[addr:]port>      | HTTP. Set to 0 to disable http server.
                                       | Addr can be an IPv4 (192.168.1.1)
                                       | or IPv6 ([3ffe:2a00:100:7031::1]) addr.
                                       | Surround IPv6 addr with square brackets.
                                       | Prepend a ':' without addr before the
                                       | listening port on the loopback address.
                                       | Default port: 3000
                                       | Examples:
                                       | -w :3000
                                       | -w 192.168.1.1:3001
                                       | -w [3ffe:2a00:100:7031::1]:3002
   [--https-port|-W] <[:]https port>   | HTTPS. See also -w above. Default: 3001
   [--local-networks|-m] <local nets>  | Local nets list (default: 192.168.1.0/24)
                                       | (e.g. -m "192.168.0.0/24,172.16.0.0/16")
   [--ndpi-protocols|-p] <file>.protos | Specify a nDPI protocol file
                                       | (eg. protos.txt)
   [--redis|-r] <fmt>                  | Redis connection. <fmt> is specified as
                                       | [h[:port[:pwd]]][@db-id] where db-id
                                       | identifies the database Id (default 0).
                                       | h is the host running Redis (default
                                       | localhost), optionally followed by a
                                       |  ':'-separated port (default 6379).
                                       | A password can be specified after
                                       | the port when Redis auth is required.
                                       | By default password auth is disabled.
                                       | On unix <fmt> can also be the redis socket file path.
                                       | Port is ignored for socket-based connections.
                                       | Examples:
                                       | -r @2
                                       | -r 129.168.1.3
                                       | -r 129.168.1.3:6379@3
                                       | -r 129.168.1.3:6379:nt0pngPwD@0
                                       | -r /var/run/redis/redis.sock
                                       | -r /var/run/redis/redis.sock@2
   [--core-affinity|-g] <cpu core ids> | Bind the capture/processing threads to
                                       | specific CPU cores (specified as a comma-
                                       | separated list)
   [--user|-U] <sys user>              | Run ntopng with the specified user
                                       | instead of nobody
   [--dont-change-user|-s]             | Do not change user (debug only)
   [--shutdown-when-done]              | Terminate after reading the pcap (debug only)
   [--zmq-encrypt-pwd <pwd>]           | Encrypt the ZMQ data using with <pwd>
   [--disable-autologout|-q]           | Disable web logout for inactivity
   [--disable-login|-l] <mode>         | Disable user login authentication:
                                       | 0 - Disable login only for localhost
                                       | 1 - Disable login for all hosts
   [--max-num-flows|-X] <num>          | Max number of active flows
                                       | (default: 131072)
   [--max-num-hosts|-x] <num>          | Max number of active hosts
                                       | (default: 131072)
   [--users-file|-u] <path>            | Users configuration file path
                                       | Default: ntopng-users.conf
   [--pid|-G] <path>                   | Pid file path
   [--packet-filter|-B] <filter>       | Ingress packet filter (BPF filter)
   [--dump-flows|-F] <mode>            | Dump expired flows. Mode:
                                       | nindex        Dump in nIndex
                                       | es            Dump in ElasticSearch database
                                       |   Format:
                                       |   es;<idx type>;<idx name>;<es URL>;<http auth>
                                       |   Example:
                                       |   es;ntopng;ntopng-%Y.%m.%d;http://localhost:9200/_bulk;
                                       |   Note: the <idx name> accepts the
                                       |   strftime() format.
                                       |
                                       | logstash      Dump in LogStash engine
                                       |   Format:
                                       |   logstash;<host>;<proto>;<port>
                                       |   Example:
                                       |   logstash;localhost;tcp;5510
                                       |
                                       | mysql         Dump in MySQL database
                                       |   Format:
                                       |   mysql;<host[@port]|socket>;<dbname>;<table name>;<user>;<pw>
                                       |   mysql;localhost;ntopng;flows;root;
                                       |
                                       | mysql-nprobe  Read from an nProbe-generated MySQL database
                                       |   Format:
                                       |   mysql-nprobe;<host|socket>;<dbname>;<prefix>;<user>;<pw>
                                       |   mysql-nprobe;localhost;ntopng;nf;root;
                                       |   Notes:
                                       |    The <prefix> must be the same as used in nProbe.
                                       |    Only one ntopng -i <interface> is allowed.
                                       |    Flows are only read. Dump is assumed to be done by nProbe.
                                       |   Example:
                                       |     ./nprobe ... --mysql="localhost:ntopng:nf:root:root"
                                       |     ./ntopng ... --dump-flows="mysql-nprobe;localhost;ntopng;nf;root;root"
   [--export-flows|-I] <endpoint>      | Export flows with the specified endpoint
   [--dump-hosts|-D] <mode>            | Dump hosts policy (default: none).
                                       | Values:
                                       | all    - Dump all hosts
                                       | local  - Dump only local hosts
                                       | remote - Dump only remote hosts
                                       | none   - Do not dump any host
   [--sticky-hosts|-S] <mode>          | Don't flush hosts (default: none).
                                       | Values:
                                       | all    - Keep all hosts in memory
                                       | local  - Keep only local hosts
                                       | remote - Keep only remote hosts
                                       | none   - Flush hosts when idle
   [--hw-timestamp-mode <mode>]          | Enable hw timestamping/stripping.
                                       | Supported TS modes are:
                                       | apcon - Timestamped pkts by apcon.com
                                       |         hardware devices
                                       | ixia  - Timestamped pkts by ixiacom.com
                                       |         hardware devices
                                       | vss   - Timestamped pkts by vssmonitoring.com
                                       |         hardware devices
   [--capture-direction]               | Specify packet capture direction
                                       | 0=RX+TX (default), 1=RX only, 2=TX only
   [--online-license-check]            | Check license online
   [--enable-taps|-T]                  | Enable tap interfaces for dumping traffic
   [--enable-user-scripts]             | Enable LUA user scripts
   [--http-prefix|-Z] <prefix>         | HTTP prefix to be prepended to URLs.
                                       | Useful when using ntopng behind a proxy.
   [--instance-name|-N] <name>         | Assign a name to this ntopng instance.
   [--community]                       | Start ntopng in community edition.
   [--check-license]                   | Check if the license is valid.
   [--check-maintenance]               | Check until maintenance is included
                                       | in the license.
   [--verbose|-v] <level>              | Verbose tracing [0 (min).. 6 (debug)]
   [--version|-V]                      | Print version and quit
   [--print-ndpi-protocols]            | Print the nDPI protocols list
   [--simulate-vlans]                  | Simulate VLAN traffic (debug only)
   [--help|-h]                         | Help

   Available interfaces (-i <interface index>):
   1. dummy0
   2. eno1
   3. any
   4. lo
   5. enp5s0
   6. enp2s0f0
   7. docker0
   8. br-ebebe1ec37ab
   9. enp2s0f0d1
   10. enp2s0f1
   11. enp2s0f1d1
   12. nflog
   13. nfqueue
   14. usbmon1
   15. usbmon2
   16. usbmon3
   17. usbmon4


Some of the most important parameters are briefly discussed here.

:code:`[--redis|-r] <redis host[:port][@db-id]>`

   Ntopng uses Redis as a backend database to store user configuration and preferences. Redis must be started before ntopng. By default the location is :code:`localhost` but this can be changed by specifying host and port where Redis is listening. In case multiple ntopng instances use same Redis server is it important, to prevent data from being overwritten, to specify the :code:`"@db-id"` string to reserve a single Redis database to every ntopng instance.

:code:`[—interface|-i] <interface|pcap>`

   At the end of the help information there a list of all available interfaces. The user can select one or more interfaces from the list so that ntopng will treat them as monitored interfaces. Any traffic flowing though monitored interfaces will be seen and processed by ntopng. The interface is passed using the interface number (e.g., :code:`-i 1`) on Windonws systems, whereas the name is used on Linux / Unix systems (e.g., :code:`-i eth0`). A monitoring session using multiple interfaces can be set up as follows:

   .. code:: bash

      ntopng -i eth0 -i eth1

   To specify a zmq interface (that allows to visualise remotely-collected flows by nProbe and cento) you should add an interface like :code:`ntopng -i tcp://<endpoint ip>/`

   An example of ntopng and nprobe communication is

   .. code:: bash

      nprobe -i eth0 -n none --zmq tcp://*:5556
      ntopng -i tcp://<nprobe host ip>:5556

   It is also possible to operate ntopng in collector mode and nProbe in probe mode (this can be useful for example when nProbe is behind a NAT) as follows (note the trailing c after the collection port)

   .. code:: bash

      nprobe -i eth0 -n none --zmq-probe-mode --zmq tcp://*:5556
      ntopng -i tcp://<nprobe host ip>:5556c

   ntopng is also able to compute statistics based on pcap traffic files:
   
   .. code:: bash

      ntopng -i /tmp/traffic.pcap 

   ntopng is also able (when PF_RING is used) to merge two interfaces into a single stream of traffic. This is useful for example when the two directions (TX+RX) of a network TAP need to be merged together. In this case, the interface name is the comma-separated concatenation of the two interface names that have to be merged, e.g.,
   
   .. code:: bash

      ntopng -i eth0,eth1 

:code:`[--http-prefix|-Z] <prefix>`

   Network admins who want to monitor their network, may want to map ntopng web interface using a reverse proxy. The main issue with reverse proxying is that the ‘/‘ URI should not be mapped to the ntopng base. Customizable prefixes for the ntopng base can be chosen using the http-prefix option.

   Generally speaking, when the http-prefix is used, ntopng web interface is accessible by pointing the browser at :code:`http://<host>:<port>/<prefix>/`


   For example, ntopng web interface can be accessed at :code:`http://localhost:3000/myntopng` if it is executed as
   
   .. code:: bash

      ntopng -Z /myntopng

   Using Apache, one would achieve the same behavior with the following http proxypass directives:
   
   .. code:: bash

      ProxyPass /myntopng/ http://192.168.100.3:3000/myntopng/
      ProxyPassReverse /myntopng/ http://192.168.100.3:3000/myntopng/

:code:`[--dns-mode|-n] <mode>`

   This option controls the behavior of the name resolution done by ntopng. User can specify whether to use full resolution, local- or remote-only, or even no resolution at all.


:code:`[--data-dir|-d] <path>`

   Ntopng uses a data directory to store several kinds of information. Most of the historical information related to hosts and applications is stored in this directory. Historical information includes round robin database (RRD) files for each application/host.


:code:`[--local-networks|-m] <local nets>`

   Ntopng characterizes networks in two categories, namely local and remote. Consequently, also hosts are characterized in either local or remote hosts. Every host that belongs to a local network is local. Similarly, every host that belongs to a remote network is remote.

   A great deal of information can be stored for local hosts, including their Layer-7 application protocols. However, additional information comes at the cost of extra memory and space used. Therefore, although a user would virtually want to mark all possible networks as local, in practice he/she will have to find a good tradeoff.

   Local networks can be specified as a comma separated list of IPv4 (IPv6) addresses and subnet masks. For example to mark three networks as local ntopng can be executed as follows:
   
   .. code:: bash

      ntopng -local-networks="192.168.2.0/24,10.0.0.0/8,8.8.8.0/24"

   In the ntopng web interface, local networks and hosts are displayed with green colors while remote networks and hosts hosts with gray colors. Extra information will be available in the contextual menus for local networks.


:code:`[—disable-login|-l]`

   By default ntopng uses authentication method to access the web GUI. Authentication can be disabled by adding the option disable-login to the startup parameters. In this case any user who access the web interface has administrator privileges.

   As mentioned above, a configuration file can be used in order to start ntopng. All the command line options can be reported in the configuration file, one per line. Options must be separated from their values using a :code:`=` sign. Comment lines starting with a :code:`#` sign are allowed as well.

.. warning::
   Unlike its predecessor, ntopng is not itself a Netflow collector. It can act as Netflow collector combined with nProbe. To perform this connection start nProbe with the :code:`--zmq` parameter and point ntopng interface parameter to the nProbe zmq endpoint. Using this configuration give the admin the possibility to use ntopng as collector GUI to display data either from nProbe captured traffic and Netflow enabled devices as displayed in the following picture.


   .. figure:: img/cli_options_ntopng_with_nprobe_architecture.png
      :align: center
      :alt: ntopng/nprobe setup

      ntopng/nprobe setup

      
