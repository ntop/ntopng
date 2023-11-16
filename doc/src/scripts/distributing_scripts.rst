Distributing Scripts
====================

Debian/Ubuntu
-------------

To distribute scripts across multiple Debian/Ubuntu machines, or
containers, or virtual machines, it may be handy to create a :code:`deb`
package containing the sources of one or more scripts. The package
only have to install script sources under
:code:`/usr/share/ntopng/scripts/scripts/`, which is the default
directory ntopng uses to load them.

A skeleton for a :code:`deb` package ready to distribute scripts is available
on `GitHub
<https://github.com/ntop/ntopng/tree/dev/packages/ubuntu/debian.ntopng-scripts>`_.
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
example scripts :ref:`Blacklisted Flows` and :ref:`Flow Flooders`.

First of all, download the `skeleton contents
<https://github.com/ntop/ntopng/tree/dev/packages/ubuntu/debian.ntopng-scripts>`_. in
a local directory, say :code:`ntopng-scripts`.

The tree of the skeleton is quite simple:

.. code:: bash

    ntopng-scripts/
    |-- DEBIAN
    |   |-- README.source
    |   `-- control
    `-- usr
        `-- share
      `-- ntopng
          `-- scripts
        `-- scripts


The root directory :code:`ntopng-scripts` contains two
sub-directories, namely :code:`DEBIAN` and
:code:`usr/share/ntopng/scripts/scripts/`.

Sub-directory :code:`DEBIAN` contains a README file which just points
to this documentation, and a :code:`control` file which is basically a
`descriptor
<https://www.debian.org/doc/debian-policy/ch-controlfields.html#binary-package-control-files-debian-control>`_
of the package. This file lists package dependencies, maintainer,
version, name and other information. Change it to make sure it fits
your needs.

The other Sub-directory :code:`usr/share/ntopng/scripts/scripts/` is
just the path which will be used by the package installer to place
the files in the destination system during package installation. Place
in this sub-directory the scripts to be installed.

To distribute :ref:`Blacklisted Flows` and :ref:`Flow Flooders`, copy
their whole script directories under  :code:`ntopng-scripts` package
sub-directory :code:`usr/share/ntopng/scripts/scripts/`. After the
copy, the final structure of the package directory :code:`ntopng-scripts`
becomes

.. code:: bash

  ntopng-scripts/
  |-- DEBIAN
  |   |-- README.source
  |   `-- control
  `-- usr
      `-- share
    `-- ntopng
        `-- scripts
      `-- scripts
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
:code:`ntopng-scripts/` and type the following

.. code:: bash

    $ dpkg-deb --build ntopng-scripts

This will product a :code:`.deb` file :code:`ntopng-scripts.deb` ready
to be distributed on a repository or manually installed with

.. code:: bash

    $ dpkg -i ntopng-scripts.deb

