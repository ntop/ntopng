Building ntopng
---------------
See [README.compilation](README.compilation) for more information.

Prior to Starting ntopng
---------------------
Please make sure that you have redis server installed and active on the same host
where ntopng will be running. If you plan to use a remote redis, please consider
using the `--redis` option to specify a remote redis server IP address and port
or a local socket. We suggest you run redis as a service so that you do not have
to start it every time you want to use ntopng.


Using ntopng as a flow collector
--------------------------------
In order to use ntopng as a flow collector with nprobe you need to start the
apps as follows:

- collector
  - `ntopng -i tcp://127.0.0.1:5556`

- probe (nProbe)
  - `nprobe --zmq "tcp://*:5556" -i ethX -n none -b 2`

You can instruct ntopng to merge onto the same interface multiple endpoints by
separating them with a comma. Example:

`ntopng -i tcp://127.0.0.1:5556,tcp://192.168.0.1:5556`


Creating Hierarchies of ntopng Instances
----------------------------------------
You can create a hierarchy of ntopngs (e.g. on a star topology, where you have many
ntopng processes on the edge of a network and a central collector) as follows:

- Remote ntopng's
  - `Host 1.2.3.4		ntopng -i ethX -I "tcp://*:3456"`
  - `Host 1.2.3.5		ntopng -i ethX -I "tcp://*:3457"`
  - `Host 1.2.3.6		ntopng -i ethX -I "tcp://*:3458"`

- Central ntopng
  - `ntopng -i "tcp://1.2.3.4:3456" -i "tcp://1.2.3.5:3457" -i "tcp://1.2.3.6:3458"`

Note that on the central ntopng you can add `-i ethX` if you want the central ntopng
monitor a local interface as well.


Accessing ntopng URLs from command line tools (no web browser)
--------------------------------------------------------------
You need to specify the user and password as specified below (please note the space in the cookie).
Note that you can optionally also specify the interface name.

`curl --cookie "user=admin; password=admin" "http://127.0.0.1:3000/lua/network_load.lua?ifname=en0"`


Using ntopng from Windows
-------------------------
1. Remember to start the redis server prior to start ntopng
2. You must start ntopng as a service using the "Services" control panel


Defaults
--------
The ntopng default user is 'admin' (without `'`) and the default
password is also 'admin' (without `'`)


Resetting admin user password
-----------------------------
1. shutdown ntopng
2. run `redis-cli del ntopng.user.admin.password`
3. restart ntopng and now the admin password has been reset


Running multiple ntopng instances on the same host
--------------------------------------------------
In order to run multiple ntopng instances independently (i.e.
they do not interfere each other), each instance must:
1. Set a different value for `-d`
2. Set a different database id for `-r`
3. Use a different http port iwth `-w`

Example:
`ntopng -d /path1 -r 127.0.0.1:6379@1 -w 3001`
`ntopng -d /path2 -r 127.0.0.1:6379@2 -w 3002`
...

Using Interface Views
---------------------
Suppose you want to start ntopng as follows `-i eth0 -i eth1`. ntopng will show you traffic
of these two interfaces without any merge so you can see exactly what happens on each interface.
If you also need an aggregated view of both interfaces you can start ntopng
as `ntopng -i eth0 -i eth1 -i view:eth0,eth1` so ntopng will create a virtual interface
that merges information from the two physical interfaces.

Using ntopng behind a Proxy
---------------------------
If you have many ntopng instances that you want to mask behind a proxy the
`-Z` option is what you look for. See the man page for more information.

Traffic with sampling rate
--------------------------
If you apply a sampling rate to capture traffic on an interface, say x100, the
traffic volume you see on ntopng will be 100 times smaller.
In order to simulate more traffic to match real traffic volume, you can apply a
scaling factor to the size of each received packet. The scaling factor can
be specified through the UI, into the interface settings.

Debugging ntopng
----------------
handle SIGPIPE nostop noprint pass
