Running ntopng as a Daemon
==========================

Ntopng can be run in daemon mode on Unix systems and optionally be run automatically on system startup. Daemon execution and status are controlled with systemd using the :code:`systemctl` script.
The systemd script is installed automatically on Unix systems as it is part of any standard ntopng installation procedure.

Daemon Configuration File
-------------------------

Ntopng configuration file is required when running it as a daemon. The configuration file has to be named :code:`ntopng.conf` and must be placed under :code:`/etc/ntopng/`. The interested reader can find above and example of a configuration file. A default configuration file is created by default when installing ntopng from any binary package.

Automatic Daemon Startup on Boot
--------------------------------

In order to launch ntopng daemon automatically on system startup, an empty file ntopng.start must be created in the same directory of the configuration files. Therefore, the directory will contain both the configuration and the startup files 

.. code:: bash

   root@devel:/etc/ntopng$ ls -lha
   total 28K
   drwxr-xr-x   2 root root 4.0K Mar 17 15:44 .
   drwxr-xr-x 117 root root  12K Mar 11 12:16 ..
   -rw-r--r--   1 root root  211 Mar 15 17:54 ntopng.conf
   -rw-r--r--   1 root root    0 Mar 17 15:44 ntopng.start

The existence of the :code:`ntopng.start` file is no longer required on systems that have systemd. On those systems, automatic ntopng daemon startup is controlled by enabling/disabling the ntopng service as

.. code:: bash

   systemctl enable ntopng
   systemctl disable ntopng

Daemon Control
--------------

On Unix systems the ntopng daemon can be controlled with systemd using the :code:`systemctl` tool. All the standard options are accepted. The options and the usage of the daemon control script are discussed below.

start
^^^^^

This option is used to start the ntopng daemon

.. code:: bash

   systemctl start ntopng

stop
^^^^

This option is used to stop an ntopng daemon instance. For example 

.. code:: bash

   systemctl stop ntopng

restart
^^^^^^^

This option causes the restart of the ntopng instance.

.. code:: bash

   systemctl restart ntopng

status
^^^^^^

This options prints the status of the ntopng daemon.

.. code:: bash

   systemctl status ntopng

Running Multiple Daemons
------------------------

Multiple ntopng daemons can be run on the same machine when
:code:`systemd` is available. In general, this is not necessary as a
single ntopng is multi-tenant and can handle multiple
interfaces. However, there are circumstances under which it is
desirable to have multiple ntopng instances running.

To run multiple ntopng daemons, :code:`systemctl` can be used. Each
daemon is identified by a :code:`<name>` so that :code:`systemctl` can
be used with this identifier when controlling the daemon. For example:

.. code:: bash

   systemctl start ntopng@eno1
   systemctl stop ntopng@eno1
   systemctl start ntopng@lo
   systemctl stop ntopng@lo

Each daemon must have its own configuration file under
:code:`/etc/ntopng` and the configuration file name must be named as
:code:`ntopng-<name>.conf`. The example above assumes two files
:code:`ntopng-eno1.conf` and :code:`ntopng-lo.conf` exist under
:code:`/etc/ntopng`.

In order to run multiple daemons on the same machine, each daemon
must be guaranteed to have its own Redis database (option :code:`-r`), its
own HTTP/HTTPS ports (options :code:`-w` and :code:`-W`), and its own
data directory (option :code:`-d`). Those options must be specified in
each daemon's configuration file.

In order to start daemons on boot, it is necessary to enable them as

.. code:: bash

   systemctl enable ntopng@eno1
   systemctl enable ntopng@eno1

Daemons which have been :code:`enable` d, will be automatically
restarted after each ntopng update. Note that backup and restore of
ntopng configuration is not supported when multiple daemons are in use.
