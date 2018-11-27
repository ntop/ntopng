Remote Assistance
=================

A common problem when requesting remote assistance is to get access to the user machine.
Usually the user machine is behind a NAT or a firewall which blocks incoming connections,
and it a problem for the non-technical user to setup port forwarding and firewall rules.

In order to ease remote assistance, ntopng integrates n2n_ and provides a web console
to enable remote access. This console is only available only in systemd-based distro such as (at the time of writing):
- Centos 7
- Ubuntu 16/18

.. warning::
As ntopng assumes that certains script files are placed in certain locations by the packages, we expect you to use the packages version of our tools what pre-place such files at the correct location. This means that if you compile ntopng from source you need to make sure the files are properly installed at the right location.

The console can be accessed from the `Remote Assistance` menu entry:

.. figure:: img/remote_assistance_menu.png
  :align: center
  :alt: Remote Assistance Menu Entry

When the remote assistance is enabled, a unique key is generated. This key should
only be provided to the ntop team via a *secure channel* (e.g. email).

.. warning::
  The secrecy of the remote assistance key is critical to avoid unauthorized access to the device

.. figure:: img/remote_assistance_settings.png
  :align: center
  :alt: Remote Assistance Settings

By enabling the remote assistance and providing the secret key to the ntop support
team, the user machine will be part of a dedicated virtual network which can be used
by the support team to connect to it, **bypassing NAT and firewalls**.

.. warning::

   ntop is not responsible for any damage, security violation or vulnerability caused by enabling remote assistance

.. warning::

   It is the user responsability to ensure that the network security policies allow virtual networks creation

If the `Enable Admin Access` flag is checked, then the support team will also be able
to connect to ntopng gui as the admin user. If it's not enabled, then gui credentials
must be provided to the support team by the user.

As long as the remote assistance is active, an icon will be displayed in the footer:

.. figure:: img/remote_assistance_footer.png
  :align: center
  :alt: Remote Assistance Status

The remote assistance service will stay active even when ntopng is stopped. This
must be manually disabled from the ntopng gui when remote assistance is concluded.

Security Considerations
-----------------------

Here are some consideration about the remote assistance security:

- All the traffic is end-to-end encrypted to prevent MITM attacks
- The remote assistance is automatically disabled after 24 hours
- By enabling remote assistance, the support team *will not have* console access
  to the machine. Console access, if necessary, must be manually configured by the user.
- Traffic forwarding via the virtual network interface is disabled to increase security





.. _n2n: https://github.com/ntop/n2n
