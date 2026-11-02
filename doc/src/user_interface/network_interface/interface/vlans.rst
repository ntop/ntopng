.. _VLANs:

VLANs
-----

The VLANs page lists the VLANs (virtual LANs, identified by the 802.1Q tag of the packets) seen on the
selected interface. Traffic without a VLAN tag is shown as *No VLAN*. The page is in the sidebar under
*Hosts* > *VLANs* and is shown only when the interface has seen VLAN traffic.

Each row shows:

- The VLAN ID, followed by its alias in square brackets when one is set
- Hosts, the number of active hosts in the VLAN
- Seen Since, the time since the first packet of the VLAN
- Score, the sum of the scores (how suspicious the traffic is) of the VLAN hosts
- Breakdown, a bar with the share of sent and received traffic
- Throughput, the current throughput
- Traffic, the total traffic exchanged

The button of the *Actions* column opens the list of the hosts in that VLAN. Its menu also has:

- *VLAN timeseries*, the historical traffic charts of the VLAN. It is disabled until VLAN
  timeseries are enabled in *Settings* > *Preferences* > *Timeseries*.
- *VLAN settings*, where the VLAN alias is set. Only administrators can use it, and it is not
  available for untagged traffic.

Both open the page of the VLAN, with the path *VLANs* / *VLAN n* on top: the *Historical Data*
tab shows the charts, the *Settings* tab the alias (leave it empty to remove it), and *Hosts* in
the top right corner lists the hosts of the VLAN.
