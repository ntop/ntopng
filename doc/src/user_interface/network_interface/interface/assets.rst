.. _Assets:

Assets Inventory
----------------

The `Network` menu, `Assets Inventory` entry, lists every host seen on the selected interface,
also after it went offline: an inventory of the devices of your network. It needs an Enterprise M
license and the asset inventory enabled in the preferences.

The page has three views:

- `Hosts`: the hosts seen on the interface, with name, MAC address, model, operating system,
  status (online or offline) and when they were first and last seen. The operating system is the
  OS tag of the asset (FreeBSD, Linux, Android, Apple or Windows). The icons next to the IP
  address show the host type, its other tags, its country and other properties: move the mouse
  over an icon to see what it means.
- `SNMP`: the devices learnt from the SNMP devices (the MAC address tables of the switches), with
  the switch and the port where they were seen. On the system interface this is the only view
  (`Pollers` menu, `SNMP Assets` entry).
- `Journal`: the history of the changes of the assets (new assets, changed fields, tags added or
  removed), with who caused each change and why. It needs an Enterprise L license and the journal
  enabled in the preferences: see :ref:`AssetsJournal`.

Click a manufacturer, an operating system or a status to show only the assets with that value
(an operating system sets the `Tag` filter). The
`Filters` menu above the table filters by the other values (VLAN, network, device type, tag...),
and `Clear filters` shows everything again. Administrators can edit a tag from the `Tag` filter
list. Click the ⤢ icon next to an IP address to open the asset details; the laptop icon opens the
live host details when the host is online (for a host seen on VLANs, the VLAN badges do it: see
`Hosts seen on several VLANs`_).

The `Actions` button of each row opens the asset details; its menu also opens the historical flows
of the asset (they need ClickHouse) and deletes it (administrators only).

Above the table:

- `Dashboard` opens the assets dashboard (it needs ClickHouse).
- `Merge Assets from Wazuh` adds the information of the Wazuh agents to the matching assets: see
  :ref:`WazuhIntegration`. It needs the Wazuh API configured in the preferences.
- `Export Assets` downloads the inventory as a CSV file, `Import Assets` loads one
  (administrators only).

Below the table, administrators can delete all the assets or the ones not seen since a date.

Hosts seen on several VLANs
^^^^^^^^^^^^^^^^^^^^^^^^^^^

A host seen with the same IP address on several VLANs is **one asset**: the VLAN is not part of
the identity of an asset. This happens, for example, when the traffic is mirrored from both the
access port of the host and a trunk, or when a router forwards the traffic of the host to other
VLANs.

- The `VLANs` column shows one badge per VLAN where the host has been seen, the active ones
  first: a green badge opens the live host on that VLAN, a grey one means that no host is active
  there right now. After the first three, a `+N` button lists all of them. The column is shown
  only when some assets have been seen on a VLAN; an asset seen only without a VLAN shows no
  badge.
- The asset is online when its host is active on any of its VLANs.
- The `VLAN` filter finds the asset by any of its VLANs.
- The MAC address is shown only when all the VLANs report the same one. When they report
  different ones (for example, behind a router the host appears with the MAC address of the
  router), the asset has no MAC address, and no manufacturer, model or device type.
- The historical flows of the asset (`Actions` menu) are the ones of all its VLANs.
- Setting or removing a user-defined tag on the host applies to the host on all its VLANs.

.. warning::

  Networks that reuse the same addresses on different VLANs (each VLAN with its own devices) get
  one asset for devices that are actually different.

Older versions recorded a host seen on several VLANs once per VLAN. When ntopng starts, it
converts those assets: the ones of the same IP address become one asset, with all their VLANs,
names, tags and history (the journal records the conversion as one event).

Asset details
^^^^^^^^^^^^^

The asset details page shows everything known about one asset: whether it is online, its IP
address and network, name, MAC address, device type, manufacturer, model and operating system,
when it was first and last seen, its tags, the switch port where it is connected (learnt from
SNMP), the other names it was seen with (DNS, DHCP, mDNS, Kerberos...), the usernames seen in its
traffic (each with a badge telling the protocol, e.g. Kerberos) and the ports where it acts as a
server (click a port to see its live flows). Click the ⤢ icon next to the IP address to open the
live host details when the host is online. For a host seen on VLANs, the `VLANs` row shows one
badge per VLAN, each one opening the live host on that VLAN when it is active (see
`Hosts seen on several VLANs`_). When a Wazuh agent runs on the host, a second card
shows the agent status, the operating system, CPU, RAM, the open ports and the network interfaces.
The `Journal` tab shows the history of the changes of the asset (it needs an Enterprise L license
and the journal enabled in the preferences).
