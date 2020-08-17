Device Management
#################

nEdge is designed to be (to a great extent) headless. Almost every
functionality of the software is configurable from the GUI. This means
that also the device management can be perfromed simply from the
GUI. However, there may be cases that require the system administrator
to manually modify some of the configurations. Such cases can be for
example the creation of custom network interfaces for the management
or for other tasks.

The following section describes how the nEdge handles the
configurations of the underlying system, and what a system
administrator can do to manually modify such configurations.

Network Interfaces
------------------

nEdge is designed to reconfigure the network interfaces of the machine
on which it is installed.

On Ubuntu 16, reconfiguration is done as follows:

1. The existing `/etc/network/interfaces` file with the current network
   configuration is saved to `/etc/network/interfaces.old`.
2. A new file `/etc/network/interfaces.d/nedge.conf` is created to
   configure network interfaces on the basis of the GUI settings
   applied.
3. A new file `/etc/network/interfaces` is created to simply source
   `/etc/network/interfaces.d/nedge.conf`.

On Ubuntu 18, reconfiguration is done as follows:

1. The existing `/etc/netplan/*.yaml` files are saved in the same directory with
   the '.old' suffix.
2. A new file `/etc/netplan/20-nedge.yaml` is created to
   configure network interfaces on the basis of the GUI settings
   applied.
3. If cloud-init is installed, the file `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`
   is created to disable cloud-init network configuration.

On Ubuntu 16 the system administrator can still configure custom
interfaces manually by creating and editing a file
`/etc/network/interfaces.d/nedge_mgmt.conf`. When the latter file
exists, it is sourced by `/etc/network/interfaces` right after
`/etc/network/interfaces.d/nedge.conf` and is never touched by nEdge.

On Ubuntu 18, the administrator can configure custom interfaces in appropriate files
under /etc/netplan *after* the nEdge system has been configured and configuration applied from
the nEdge GUI.
