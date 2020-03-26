
Running on Windows
==================
on Windows ntopng runs as service. The ntopng installer registers the service and automatically starts is as shown below.

.. figure:: ../img/what_is_ntopng_running_on_windows.png
  :align: center
  :alt: The Windows Services Manager

  The Windows Services Manager

You can start ntopng from cmd.exe only for debug purposes or for manipulating the service settings. In this case you can start cmd.exe (i.e. Windows Commands Prompt) and navigate to the ntopng installation directory (i.e. C:\\Program Files\\ntopng). Commands are issued after a :code:`/c` that stands for *console*. For example to display the inline help it suffices to run

.. code:: bash

   ntopng /c -h

.. warning::

   ntopng requires the :code:`redis` service to be up and running or it will not start. Make sure this service is running and auto-started on boot. Check its status from the Services application.
   
List Monitored Interfaces
----------------------------
As network interfaces on Windows can have long names, a numeric index is associated to the interface in order to ease the ntopng configuration. The association between interface name and index is shown in the inline help.

.. code:: bash

   c:\Program Files\ntopng>ntopng /c -h
   [...]
   Available interfaces (-i <interface index>):
   1. Intel(R) PRO/1000 MT Desktop Adapter
   {8EDDEFE3-D6DB-4F9B-9EDF-FBC0BFF67F3C}
   [...]

In the above example the network adapter Intel(R) PRO/1000 MT Desktop is associated with index 1. To select this adapter ntopng needs to be started with :code:`-i 1` option.

Manipulating ntopng Windows Service Settings
--------------------------------------------
Windows services are started and stopped using the Services application part of the Windows administrative tools. When ntopng is used as service, command line options need to be specified at service registration and can be modified only by removing and re-adding the service. The ntopng installer registers ntopng as a service with the default options. The default registered service options can be changed using these commands:

.. code:: bash

   c:\Program Files\ntopng>ntopng /r
   ntopng removed.

   c:\Program Files\ntopng>ntopng /i -i 1
   ntopng installed.
   NOTE: the default password for the 'admin' user has been set to 'admin'.
   c:\Program Files\ntopng>


Troubleshooting
---------------
ntopng requires the redis service to be activated in order to start. You can check redis status from the Services application.

In some Windows PCs, in particular those with WiFi adapters, ntopng might not be able to detect these adapters. Shall this be the case, we suggest you to deinstall the Win10Pcap drivers that are installed with ntopng and move to the ncap Windows drivers that can be installed from `ncap Windows drivers
<https://nmap.org/npcap/windows-10.html>`_.

