Icinga2 Integration
===================

ntopng integrates with `Icinga2 <https://icinga.com/>`_ by means of a check plugin
:code:`check_ntopng.py`, open source and freely available.

The plugin connects to the ntopng REST API to query for host
alerts. Specifically, it queries:

  - Host engaged alerts, to capture ongoing host network issues (for example, the host is a victim of a SYN flood attack)
  - Host flow alerts, to capture suspicious or malicious flows involving a particular host (for example, the host has been contacted by a blacklisted IP).

The plugin code is available at
https://github.com/ntop/ntopng/tree/dev/tools/icinga2 along with other
files necessary for Icinga2 to properly interface with the plugin.
The integration has been announced at
https://www.ntop.org/ntopng/integrating-ntopng-with-icinga2/.

Plugin Installation and Configuration
-------------------------------------

To properly setup :code:`check_ntopng.py`, the following steps are
necessary:

  - :code:`check_ntopng.py` needs to be placed inside the Icinga2 plugins
    directory
  - An Icinga2 :code:`CheckCommand` needs to be created so that Icinga2 will know how
    to interface with the plugin
  - Icinga2 :code:`Service` s need to be created to tell Icinga2 to execute the plugin
    as part of its hosts monitoring operations

Let's see how to perform these steps in detail.

First, download the plugin file `check_ntopng.py <https://raw.githubusercontent.com/ntop/ntopng/dev/tools/icinga2/check_ntopng.py>`_ into the :code:`PluginContribDir`
directory. The path to this directory can be found inside Icinga2
:code:`constants.conf` file, which is typically located under
:code:`/etc/icinga2/` under Linux.

To find the path to this directory out, it suffices to :code:`grep` file
:code:`constants.conf` for :code:`PluginContribDir`

.. code:: bash

   cat /etc/icinga2/constants.conf | grep PluginContribDir
   const PluginContribDir = "/usr/lib/nagios/plugins"

Here the :code:`PluginContribDir` path is :code:`/usr/lib/nagios/plugins`.

Once the plugin is in place, it is necessary to download file
`check_ntopng_command.conf
<https://raw.githubusercontent.com/ntop/ntopng/dev/tools/icinga2/etc/icinga2/conf.d/check_ntopng_command.conf>`_
in :code:`/etc/icinga2/conf.d/` or in any other directory which is
read by Icinga2 upon startup. The file contains the definition of a
:code:`CheckCommand` object, necessary to tell Icinga2 how to
interface  with the plugin.

Then, download and place file `check_ntopng_service.conf
<https://raw.githubusercontent.com/ntop/ntopng/dev/tools/icinga2/etc/icinga2/conf.d/check_ntopng_service.conf>`_
in :code:`/etc/icinga2/conf.d/` or in any other directory which
Icinga2 is aware of. This file contains the definition of two
:code:`Service` objects, one to check for host engaged alerts
("ntopng-icinga-host-health") and another one to check for host flow
alerts ("ntopng-icinga-host-flows-health"). Those two files will
automatically apply the services to all the Icinga2 monitored hosts.

Finally, a bunch of constants should be configured to tell Icinga2 how
to properly reach and authenticate to the ntopng REST API. Such
constants go inside file :code:`constants.conf`, the same file used above to
locate the :code:`PluginContribDir` directory.

Constants are the following

.. code:: bash

   # cat /etc/icinga2/constants.conf | grep Ntopng
   /* Ntopng */
   const NtopngHost = "127.0.0.1"
   const NtopngPort = 3000
   const NtopngInterfaceId = 0
   const NtopngUser = "admin"
   const NtopngPassword = "admin1"
   const NtopngUseSsl = false
   const NtopngUnsecureSsl = false

:code:`NtopngHost` and :code:`NtopngPort` tell Icinga2 how to connect
to the ntopng REST API and :code:`NtopngUseSsl` whether SSL has to be
used for the connection (:code:`NtopngUnsecureSsl` set to true
prevents the plugin from checking SSL certificates validity).
When the ntopng authentication is enabled, :code:`NtopngUser` and
:code:`NtopngPassword` are necessary to indicate a user/password pair
which will be used by Icinga2 to authenticate to the REST
API. Finally, :code:`NtopngInterfaceId` is used to tell Icinga2 the id
of the ntopng interface which is responsible for the monitoring of traffic.

Example
-------

Let's say there is a ntopng instance running on :code:`192.168.2.225`. ntopng
is monitoring two interfaces, namely the loopback :code:`lo` and
:code:`enp2s0f0`, and it only responds to HTTPS requests on port
:code:`443`.

.. code:: bash

   ntopng -i lo -i enp2s0f0 -w 0 -W 443

Interface :code:`enp2s0f0` is connected to a mirror port of a switch
and receives a copy of all the traffic of local network :code:`192.168.2.0/24`,
local network which is also monitored by Icinga2.

A user :code:`admin` is allowed to access the ntopng GUI, upon successful
authentication with password :code:`ntopngIcinga2`. User
:code:`admin`, by visiting the ntopng GUI page :code:`if_stats.lua`,
finds out that :code:`enp2s0f0` has been assigned an :code:`id` equal
to :code:`2` by ntopng.

Given the information above, one would configure Icinga2
:code:`constants.conf` as follows

.. code:: bash

   # cat /etc/icinga2/constants.conf | grep Ntopng
   /* Ntopng */
   const NtopngHost = "192.168.2.225"
   const NtopngPort = 443
   const NtopngInterfaceId = 2
   const NtopngUser = "admin"
   const NtopngPassword = "ntopngIcinga2"
   const NtopngUseSsl = true
   const NtopngUnsecureSsl = false

After changing the :code:`constants.conf` one can restart Icinga2 to
make sure changes become effective. After the restart, Icinga2 will
take each of the monitored hosts in :code:`192.168.2.0/24` and, by means of
the plugin, will ask ntopng to see if there are any alerts, possibly changing
its services from OK to CRITICAL.
