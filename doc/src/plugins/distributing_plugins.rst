Distributing Plugins
====================

Debian/Ubuntu
-------------

To distribute plugins across multiple Debian/Ubuntu machines, or
containers, or virtual machines, it may be handy to create a :code:`deb`
package containing the sources of one or more plugins. The package
only have to install plugin sources under
:code:`/usr/share/ntopng/scripts/plugins/`, which is the default
directory ntopng uses to load them.

A skeleton for a :code:`deb` package ready to distribute plugins is available
on `GitHub
<https://github.com/ntop/ntopng/tree/dev/packages/ubuntu/debian.ntopng-plugins>`_.
The skeleton can be used to create a minimal :code:`.deb` file. It is
suitable to produce a :code:`.deb` for personal use but it may not be
stringent enough if the package needs to be included in official Debian /
Ubuntu repositories. Comprehensive instructions and rules can be found
in the `Debian New Maintainer's Guide
<http://www.debian.org/doc/maint-guide/>`_ and in the `Ubuntu Packaging
Guide <http://packaging.ubuntu.com/html/>`_.

Example
~~~~~~~

The following example shows how to create a :code:`deb` package to distribute the
example plugins :ref:`Blacklisted Flows` and :ref:`Flow Flooders`.

First of all, download the `skeleton contents
<https://github.com/ntop/ntopng/tree/dev/packages/ubuntu/debian.ntopng-plugins>`_. in
a local directory, say :code:`ntopng-plugins`.

The tree of the skeleton is quite simple:

.. code:: bash

    ntopng-plugins/
    |-- DEBIAN
    |   |-- README.source
    |   `-- control
    `-- usr
        `-- share
      `-- ntopng
          `-- scripts
        `-- plugins


The root directory :code:`ntopng-plugins` contains two
sub-directories, namely :code:`DEBIAN` and
:code:`usr/share/ntopng/scripts/plugins/`.

Sub-directory :code:`DEBIAN` contains a README file which just points
to this documentation, and a :code:`control` file which is basically a
`descriptor
<https://www.debian.org/doc/debian-policy/ch-controlfields.html#binary-package-control-files-debian-control>`_
of the package. This file lists package dependencies, maintainer,
version, name and other information. Change it to make sure it fits
your needs.

The other Sub-directory :code:`usr/share/ntopng/scripts/plugins/` is
just the path which will be used by the package installer to place
the files in the destination system during package installation. Place
in this sub-directory the plugins to be installed.

To distribute :ref:`Blacklisted Flows` and :ref:`Flow Flooders`, copy
their whole plugin directories under  :code:`ntopng-plugins` package
sub-directory :code:`usr/share/ntopng/scripts/plugins/`. After the
copy, the final structure of the package directory :code:`ntopng-plugins`
becomes

.. code:: bash

  ntopng-plugins/
  |-- DEBIAN
  |   |-- README.source
  |   `-- control
  `-- usr
      `-- share
    `-- ntopng
        `-- scripts
      `-- plugins
          |-- blacklisted
          |   |-- alert_definitions
          |   |   `-- alert_flow_blacklisted.lua
          |   |-- manifest.lua
          |   |-- status_definitions
          |   |   `-- status_blacklisted.lua
          |   `-- checks
          |       `-- flow
          |           `-- blacklisted.lua
          `-- flow_flood
        |-- alert_definitions
        |   `-- alert_flows_flood.lua
        |-- manifest.lua
        `-- checks
            |-- host
            |   |-- flow_flood_attacker.lua
            |   `-- flow_flood_victim.lua
            `-- network
          `-- flow_flood_victim.lua


Now everything is ready and setup for the actual creation of the
:code:`deb`. Just jump in the directory which contains
:code:`ntopng-plugins/` and type the following

.. code:: bash

    $ dpkg-deb --build ntopng-plugins

This will product a :code:`.deb` file :code:`ntopng-plugins.deb` ready
to be distributed on a repository or manually installed with

.. code:: bash

    $ dpkg -i ntopng-plugins.deb

