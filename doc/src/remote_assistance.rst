Remote Assistance
=================

A common problem when requesting remote assistance is to get access to the user machine.
Usually the user machine is behind a NAT or a firewall which blocks incoming connections,
and it a problem for the non-technical user to setup port forwarding and firewall rules.

In order to ease remote assistance, ntopng integrates n2n_ and provides a web console
to enable remote access. This console is available only in systemd-based distro such as (at the time of writing):

- Centos 7
- Ubuntu 16/18
- Debian 9

.. warning::
  ntopng assumes that certains script files are placed in certain locations, as installed by the ntopng prebuild package.
  This means that, if ntopng is compiled from source, special care must be taken to place these files at the correct locations
  in order to make remote assistance available.

The console can be accessed from the `Remote Assistance` menu entry:

.. figure:: img/remote_assistance_menu.png
  :align: center
  :alt: Remote Assistance Menu Entry

When the remote assistance is enabled, the machine running ntopng will take part
to a dedicated virtual network. By running the connection script, which can be
downloaded from the gui, any linux system with the n2n software can take part to
the machine virtual network to provide remote assistance **bypassing NAT and firewalls**.
The script can be run from the terminal as follows:

.. code:: bash

    chmod +x n2n_assistance.sh
    ./n2n_assistance.sh

.. warning::

  The connection script contains connection credentials so it must be sent only to trusted peers

.. figure:: img/remote_assistance_settings.png
  :align: center
  :alt: Remote Assistance Settings

By enabling the remote assistance and providing the connection script to the ntop support
team, the user can receive remote assistance. When remote assistance is enabled, the ntopng instance will be available at IP address 192.168.166.1

If the `Temporary Admin Access` flag is checked, then the support team will also be able
to connect to ntopng GUI as the admin user by using the same credentials of the connection
script. If it's not enabled, then GUI credentials must be provided to the support team by the user.

.. warning::

   ntop is not responsible for any damage, security violation or vulnerability caused by enabling remote assistance

.. warning::

   It is the user responsability to ensure that the network security policies allow virtual networks creation

Remote Assistance Status
------------------------

As long as the remote assistance is active, an icon will be displayed in the footer:

.. figure:: img/remote_assistance_footer.png
  :align: center
  :alt: Remote Assistance Status

By clicking on it, it's possible to check the service status and log.

.. figure:: img/remote_assistance_status.png
  :align: center
  :alt: Remote Assistance Status

The remote assistance service will stay active even when ntopng is stopped. This
must be manually disabled from the ntopng GUI when remote assistance is concluded.

Security Considerations
-----------------------

Here are some consideration about the remote assistance security:

- All the traffic is end-to-end encrypted to prevent MITM (Man In The Middle) attacks
- The remote assistance is automatically disabled after 24 hours
- By enabling remote assistance, the support team *will not have* console access
  to the machine. Console access, if necessary, must be manually configured by the user.
- Traffic forwarding via the virtual network interface is disabled to increase security





.. _n2n: https://github.com/ntop/n2n
