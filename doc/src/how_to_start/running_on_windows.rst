Running on Windows
==================
ntopng can be run either as service or as application (i.e. you can start it from :code`cmd.exe`). The ntopng installer registers the service and automatically starts is as shown below.

.. figure:: ../img/what_is_ntopng_running_on_windows.png
  :align: center
  :alt: The Windows Services Manager

  The Windows Services Manager

In order to interact with ntopng from the command line, fire up a Windows Commands Promt and navigate to the ntopng installation directory. You may need to execute the commands promo with Administrator privileges. Commands are issued after a :code:`/c` that stands for *console*. For example to display the inline help it suffices to run

.. code:: bash

   ntopng /c -h


Specify Monitored Interfaces
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

Execution as a Windows Service
------------------------------
Windows services are started and stopped using the Services application part of the Windows administrative tools. When ntopng is used as service, command line options need to be specified at service registration and can be modified only by removing and re-adding the service. The ntopng installer registers ntopng as a service with the default options. The default registered service options can be changed using these commands:

.. code:: bash

   c:\Program Files\ntopng>ntopng /r
   ntopng removed.

   c:\Program Files\ntopng>ntopng /i -i 1
   ntopng installed.
   NOTE: the default password for the 'admin' user has been set to 'admin'.
   c:\Program Files\ntopng>
