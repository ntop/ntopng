Running ntopng as a Daemon
==========================
Ntopng can be run in daemon mode on unix systems and optionally be run automatically on system startup. Daemon execution and status are controlled using the script :code:`/etc/init.d/ntopng`. The script is installed automatically on unix systems as it is part of any standard ntopng installation procedure. Newer systems that support systemd use :code:`systemctl` to control daemon execution an status.

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
ntopng daemon is controlled with the script :code:`/etc/init.d/ntopng`. The script accepts different options. Calling the script without options yields the following brief help

.. code:: bash

   /etc/init.d/ntopng
   Usage: /etc/init.d/ntopng {start|force-start|stop|restart|status}

On unix systems that support systemd, the demon can only be controlled with :code:`systemctl`. All the standard options are accepted. The options and the usage of the daemon control script are discussed below.

start
^^^^^
This option is used to start the ntopng daemon

.. code:: bash

   /etc/init.d/ntopng start
   * Starting ntopng
   .done.

On unix systems with systemd the daemon is started as

.. code:: bash

   systemctl start ntopng

force-start
^^^^^^^^^^^
Equivalent to start. Not available on unix systems with systemd.

stop
^^^^
This option is used to stop an ntopng daemon instance. For example 

.. code:: bash

   /etc/init.d/ntopng stop
   * Stopping ntopng
   .done.

To stop the daemon on a unix system with systemd use

.. code:: bash

   systemctl stop ntopng

restart
^^^^^^^
This option causes the restart of a daemon associated to a given interface, e.g., 

.. code:: bash

   /etc/init.d/ntopng restart
   * Stopping ntopng
   * Starting ntopng
   .done.

To restart the daemon on a unix system type

.. code:: bash

   systemctl restart ntopng

status
^^^^^^
This options prints the status of a daemon associated to a given interface, e.g., 

.. code:: bash

   /etc/init.d/ntopng status
   ntopng running as 5623

To print the status of the ntopng daemon on a unix system with systemd type

.. code:: bash

   systemctl status ntopng
