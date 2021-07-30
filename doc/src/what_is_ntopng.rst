What is ntopng
##############

ntopng is a passive network monitoring tool focused on flows and
statistics that can be obtained from the traffic captured by the
server.

Installation
============

ntopng is open source and available on `GitHub
<https://github.com/ntop/ntopng>`_. In addition, pre-compiled, binary
ntopng packages are available both for Linux and Windows. Installation
instructions for binary packages are available below.

Installing on Linux
-------------------

Installation instructions can be found at
http://packages.ntop.org/. Development and stable builds are
available. Stable builds are intended for production environments whereas
development builds are intended for testing or early feature access.

Installing on MacOS
-------------------

MacOS installation packages can be found at
http://packages.ntop.org/ and are installed with a GUI.
ntopng requires Redis to be installed in order to start. During the ntopng installation,
if Redis is not present, Redis is installed and activated, otherwise the one already installed on
the system is used. After the installation, ntopng is started and active on local port 3000
(i.e. ntopng is available at http://127.0.0.1:3000). If you want to uninstall ntopng you can
open a terminal and type :code:`sudo /usr/local/bin/ntopng-uninstall.sh`

To enable geolocation, MacOS packages require database files to be manually placed under :code:`/usr/local/share/ntopng/httpdocs/geoip`. Detailed instructions on how to obtain database files and install them are available at https://github.com/ntop/ntopng/blob/dev/doc/README.geolocation.md/. Once the files have been downloaded and placed in the folder, a restart of ntopng is necessary to read load them.

The ntopng configuration file is installed in /usr/local/etc/ntopng/ntopng.conf that can be edited
(as privileged user) with a text editor.

The ntopng service can be started/stopped using the launchctl command:

- [Start] :code:`sudo launchctl load /Library/LaunchDaemons/org.ntop.ntopng.plist`
- [Stop] :code:`sudo launchctl unload /Library/LaunchDaemons/org.ntop.ntopng.plist`

Installing on Windows
---------------------

Only the development build binary is available for Windows. The binary can
be downloaded from the `Windows package repository
<https://packages.ntop.org/Windows/>`_.

Download the ntopng :code:`zip` file from the link above, locate it in
the filesystem, and unzip it to access the actual ntopng
installer. Double-click on the installer. The installation procedure
will start and ntopng will be installed, along with its dependencies.

The installation procedure installs

- ntopng
- `Microsoft Visual C++ Redistributable
  <https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads>`_
- `Redis <https://redis.io/>`_

.. note::

   If upgrading from an earlier version of ntopng for Windows, it is
   safe to skip the installation of any ntopng dependency. It is safe
   to respond 'No' or click 'Cancel' when prompted to install 
   Microsoft Visual C++ Redistributable, and Redis.

By default, the ntopng installer comes without capture drivers. You need to
install manually `npcap drivers <https://nmap.org/npcap/>`_. If Wireshark is
already installed on Windows, then `npcap drivers <https://nmap.org/npcap/>`_
are already installed and no drviver installation is necessary.

In case you see a message as the one below
 
.. figure:: ./img/missing_pcap.png

it means that your capture drivers have not been properly installed and that you have to install them as described in this section.


.. note::   

   If during installation the installer complains for missing MSVCR120.DLL or MSVCR120P.DLL please
   download `Visual C++ Redistributable Package <https://support.microsoft.com/en-us/help/3179560/update-for-visual-c-2013-and-visual-c-redistributable-package>`_

Installing on FreeBSD
---------------------

Installation instructions can be found at http://packages.ntop.org/.

Installing on OPNsense/pfSense
------------------------------

OPNsense installation instructions are available in the :ref:`OPNsenseIntegration` integration page. pfSense installation instructions are available in the :ref:`pfSenseIntegration` integration page.

Software Updates
================

General instructions for updating the software can be found at
http://packages.ntop.org/ together with the installation instructions.
Depending on the Operating System, ntopng supports also automatic updates
through the GUI as described in the below sections.

Updating the Software on Linux
------------------------------

Instructions for updating the software via command line can be found
at http://packages.ntop.org/. For example on Ubuntu/Debian systems the
below commands will update the repository, check for updates and install
the latest software update if any:

.. code:: bash

   apt-get update
   apt-get upgrade

Alternatively, it is also possible to check for software updates through
the Web interface using the top-right menu as shown in the picture below.
The system automatically checks for new updates overnight and report the
new version if any. Otherwise it is also possible to force the check for
new versions by clicking on *Check for updates* and waiting a few seconds
(up to 1 minute) for the check to be performed.

.. figure:: img/software_updates_check.png
  :align: center
  :width: 400
  :alt: Check for Updates

  Check for Updates Menu

In the same menu, whenever a new ntopng version is available, it is possible
to install it by clicking on *Install update*, as depicted below.

.. figure:: img/software_updates_install.png
  :align: center
  :width: 400
  :alt: Install Update

  Install Update

It is also possible to configure ntopng to self-update itself overnight, 
this can be enabled through *Settings* > *Preferences* > *Updates*. By
default ntopng does not update itself overnight as it requires restarting
the service, but if you want you can enable this preference and let ntopng
do everything automatically.
 
.. figure:: img/software_updates_auto.png
  :align: center
  :alt: Automatic Updates

  Automatic Updates Setting
  
Versions
========

The ntopng software comes in four versions: Community, Professional, Enterprise M, Enterprise L
each version unlocks additional features with respect to the smaller one.

A full list of features and a comparison table is available in the ntopng 
`Product Page <https://www.ntop.org/products/traffic-analysis/ntop/>`_

ntopng Community
----------------

The Community version is free to use and open source. The full source code can be found on `Github <https://github.com/ntop/ntopng>`_.

ntopng Professional
-------------------

The Professional version offers some extra features with respect to the Community, which are particularly useful for SMEs, including graphical reports, traffic profiles and LDAP authentication.

ntopng Enterprise M
-------------------

The Enterprise M version offers some extra features with respect to the Professional version, which are particularly useful for large organizations, including SNMP support, fast MySQL export, advanced alerts management, high performance flow indexing.

ntopng Enterprise L
-------------------

The Enterprise L version offers some extra features with respect to the Enterprise M version, including Identity Management (the ability to correlate users to traffic). This version also unlocks n2disk 1 Gbit (Continuous Recording) and nProbe Pro (Flow Collection) with no need for additional licenses.

Licensing
=========

The Community edition does not need any license. Professional and Enterprise
versions require a license. ntopng automatically switches to one of these four versions, 
depending on the presence of a license.

License is per-server and is released according to the EULA (End User
License Agreement). Each license is perpetual (i.e. it does not
expire) and it allows to install updates for one year since
purchase/license issue. This means that a license generated on
1/1/2021 will be able to activate new versions of the software until
12/31/2021. If you want to install new versions of the software release
after that date, you need to renew the maintenance or avoid further
updating the software. For source-based ntopng you can refer to the
GPL-v3 License.

ntopng licenses are generated using the orderId and email you provided
when the license has been purchased on https://shop.ntop.org/.

.. note::

   if you are using a VM or you plan to move licenses often, and you
   have installed the software on a server with Internet access, you
   can add :code:`--online-license-check` to the application command
   line (example: :code:`ntopng -i eth0 --online-license-check`) so
   that at startup the license is validated against the license
   database. The :code:`--online-license-check` option also supports
   http proxy setting the :code:`http_proxy` environment variable
   (example: :code:`export http_proxy=http://<ip>:<port>`).

Once the license has been generated, it can be applied to ntopng
simply by visiting page "Settings"->"License" of the web GUI and
pasting the license key in the license form.

Alternatively, the license key can be placed in a one-line file
:code:`ntopng.license`:

- On Linux, the file must be placed in :code:`/etc/ntopng.license`
- On Windows, the file must be placed in :code:`Program
  Files/ntopng/ntopng.license`

.. note::

   An ntopng restart is recommended once the license has been applied
   to make sure all the new functionalities will be unlocked.

.. _Geolocation:

Geolocation
===========

ntopng supports geolocation of IP addresses. Databases of multiple vendors can be used interchangeably.

.. note::

   Detailed installation instructions are available at `this page
   <https://github.com/ntop/ntopng/blob/dev/doc/README.geolocation.md>`_.

