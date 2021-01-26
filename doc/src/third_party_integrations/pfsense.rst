.. _OPNsenseIntegration:

pfsense
########

ntopng Pro/Enterprise can be installed on pfsense using 
the command line. This requires the configuration of the FreeBSD
repository as described at https://packages.ntop.org/FreeBSD/.

Repository Configuration
========================

Log into the pfsense Shell as administrator (select option 8).

.. figure:: ../img/pfsense_shell.png
  :align: center
  :alt: pfsense Shell

  pfsense Shell

And install the repository using the command provided at https://packages.ntop.org/FreeBSD/
(you can cut&paste the command below).

.. code:: bash

   pkg add https://packages.ntop.org/FreeBSD/FreeBSD:11:amd64/latest/ntop-1.0.txz

The output should look like the below.

.. figure:: ../img/pfsense_repo_installation.png
  :align: center
  :alt: ntop Repo Installation

  ntop Repository Installation

Package Installation
====================

After logging into the pfsense Shell, run the below command to install
the ntopng package:

.. code:: bash

   pkg install ntopng

License Configuration
=====================

.. note::

   ntopng Community Edition is free of charge and does not require a license. Skip this
   section if you want to run ntopng in Community mode.

Run the below command in order to get all the information required
by the license generator (*Version* and *System ID*).

.. code:: bash

   /usr/local/bin/ntopng -V

The license should be installed under /usr/local/etc/ntopng.license

.. code:: bash

   echo LICENSE_KEY > /usr/local/etc/ntopng.license

ntopng Configuration
====================

A sample ntopng configuration file is located under /usr/local/etc/ntopng/ntopng.conf.sample,
please copy it to /usr/local/etc/ntopng.conf and open it with the preferred editor in case 
the default settings should be modified. Add a new line with the *--community* option to run
ntopng in Community mode.

Enable ntopng and redis with the below commands:

.. code:: bash

   sysrc redis_enable="YES"
   sysrc ntopng_enable="YES"

Make sure the redis service is running:

.. code:: bash

   service redis start

Run the ntopng service:

.. code:: bash

   service ntopng start

