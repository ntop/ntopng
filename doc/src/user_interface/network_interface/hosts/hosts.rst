.. _Hosts:

Hosts
#####

Hosts is a menu of the sidebar that contains a bunch of links to host-
related information pages. The dropdown is as follows:

.. figure:: ../../../img/web_gui_hosts_dropdown.png
  :align: center
  :alt: Hosts Dropdown

  The Hosts Dropdown Menu

Host-related information pages available have the following content

- Hosts: shows all hosts seen
- MAC addresses: shows all MAC addresses seen
- Assets: shows all the assets available (Active or Inactive)

Hosts
-----

The Hosts page shows the devices (hosts) that ntopng sees on the selected network interface.
It has two tabs:

- *Active Hosts*: the hosts that are exchanging traffic right now.
- *Local Hosts Activity*: how much traffic your local hosts made over a period of time.

If you open the page from an Autonomous System (for example from the AS list), an *AS Info*
link appears at the top right: it opens the details of that Autonomous System.

Active Hosts
^^^^^^^^^^^^

.. figure:: ../../../img/web_gui_hosts_all.png
  :align: center
  :alt: Active Hosts

  The Active Hosts Tab

This tab lists all the hosts that are active now, both inside your network (local) and
outside it (remote). The list refreshes by itself every 10 seconds. Click a column title to
sort the list by that column.

For each host you can see:

- its IP address, with small icons that describe it: the operating system, the country flag,
  **L** for a local host, **R** for a remote host, and others (for example a blacklisted host)
- its name
- its VLAN (shown only if your network uses VLANs)
- how many connections (flows) and alerts it has, and its score (the higher, the more
  suspicious its traffic)
- how long ago it was first seen
- how much traffic it sends and receives, its current speed and its total traffic

To open all the details of a host, click the button in the *Actions* column, or the small
arrow icon next to its IP address. The menu next to the button also shows the connections
(flows) of the host.

Finding hosts
"""""""""""""

Use the filters above the list to see only some hosts, for example only the local ones, only
those of a VLAN or of a group (host pool). When there are many filters, they are inside the
*Filters* button. Each active filter is shown above the list: click the **x** to remove it,
or *Clear filters* to see all the hosts again.

You can also filter by clicking a value in the list: for example click a country flag to see
only the hosts of that country, or the **L** badge to see only the local hosts.

The filters you choose are kept in the address of the page, so you can bookmark it or send it
to a colleague.

Local Hosts Activity
^^^^^^^^^^^^^^^^^^^^

.. note::

   This tab needs an Enterprise M license (or higher), and the host timeseries must be
   enabled in the Preferences. If one of them is missing, the tab is greyed out: move the
   mouse over it to see what is needed.

This tab shows how much traffic each local host made in the period you choose with the time
selector above the list (*Live* shows the traffic right now).

For each host you can see the traffic sent and received, the traffic with other local hosts
and with remote hosts, and the total. The *Availability* column shows one square for each part
of the period: grey means no traffic, and the darker the green, the more traffic the host made.

With *Hosts Type* you choose which hosts to list: those with traffic (the default), those
without traffic, all the visible ones or the hidden ones.

From the *Actions* column you can:

- see the traffic chart of the host (only for the hosts that are active now)
- hide a host you are not interested in, so it no longer appears in the list
- show a hidden host again (first choose *Hidden* in *Hosts Type* to find it)

Only administrators can hide or show hosts.

Host Details
^^^^^^^^^^^^

The host details pages provide many insights on the information collected for an host.

The navigation bar entries are discussed below. Since the entries are contextual,
some of them may be hidden.

Home
^^^^

*Home* is the default view of the Host Details page and provides detailed information including host MAC
Address (or the last router MAC address if the host is remote), IP Address (with network mask if detected),
a toggle to activate/deactivate alerts for the host, a checkbox to enable packet dump for the specific host,
symbolic hostname (or IP address), location (local or remote), date and time of first and last packet seen
for the host, traffic breakdown, amount of traffic packets received/sent, number of flows as client/server
host. All of this information is also available in JSON format by clicking on the ‘Download’ link. The heat
map provides the Activity Map for each host. Each box represents one minute of traffic. By default, Activity
Map shows the last six hours, but it is possible to set a different timeframe using the controls.

.. figure:: ../../../img/web_gui_host_details.png
  :align: center
  :alt: Host Details

  The Home View of the Host Details Page


Also in case Wazuh is integrated in ntopng (see `Wazuh Integration`_ for more details), a button with the possibility to jump to Wazuh alerts will appear, giving the
possibility to instatly check the Wazuh Alerts of an host.

.. figure:: ../../../img/host_details_wazuh.png
  :align: center
  :alt: Host Details

  Wazuh Button


.. note::

   Wazuh link is enabled only for Local Hosts.


.. _`Wazuh Integration`: ../../../third_party_integrations/wazuh.html


Traffic
^^^^^^^

The Traffic Page provides Layer-4 protocol statistics for the host. A pie chart showing L-4 protocol
breakdown is show at the top of page. A table with detailed statistics is shown below the chart.

.. figure:: ../../../img/web_gui_host_details_traffic.png
  :align: center
  :alt: Host Traffic View

  The Traffic View of the Host Details Page

Packets
^^^^^^^

Packets page provides pie charts with packet size distribution, both for sent and received packets.

.. figure:: ../../../img/web_gui_host_details_packets.png
  :align: center
  :alt: Host Packets View

  The Packets View of the Host Details

Ports
^^^^^

Ports page provides pie charts with traffic statistics grouped by port. A chart is available for client ports
and another one is available for server ports.

.. figure:: ../../../img/web_gui_host_details_ports.png
  :align: center
  :alt: Host Ports View

  The Ports View of the Host Details Page

Applications
^^^^^^^^^^^^

Using the DPI information, this page provides in pie chart and tabular format the amount of traffic divided
by application. An additional pie chart provides a statistics about protocol type. A click on the protocol
name redirects the user to the page with detailed statistics about the selected protocol.

.. figure:: ../../../img/web_gui_host_details_protocols.png
  :align: center
  :alt: Host Protocols View

  The Protocols View of the Host Details Page

DNS
^^^

The chart and the table displayed on this page report DNS statistics, such as the number of queries, their
type (e.g., A, AAAA, PTR, and so on), and possible errors.

.. figure:: ../../../img/web_gui_host_details_dns.png
  :align: center
  :alt: Host DNS View

  The DNS View of the Host Details Page

TLS
^^^

.. figure:: ../../../img/web_gui_host_details_tls_info.png
  :align: center
  :alt: Host Protocols View

  The TLS View of the Host Details Page

ntopng registers the `JA3`_ TLS fingerprints of an host (either when the host is a client or a server) along with their the number of uses.
As explained in the `Flows section`_, this information is very important in order to uncover possible threats on the encrypted
traffic. By clicking on the signature it is possible to manually check if the JA3 signature
corresponds to a known malware into the `abuse.ch database`_.

By taking a snapshot of the signatures registered on an host it is possible to know, for example,
if the host has installed a new program or has updated an existing one. This may be very important
on environments where the programs installed into an host are not supposed to change.

By enabling the `nProbe Agent integration`_, this view can be further augmented
with the name of the process which initiated or received the TLS connection.

.. _`nProbe Agent integration`: https://www.ntop.org/guides/ntopng/using_with_nprobe_agent.html
.. _`abuse.ch database`: https://sslbl.abuse.ch/ja3-fingerprints
.. _`JA3`: https://github.com/salesforce/ja3
.. _`Flows section`: ../flows/flows.html#tls-information

SSH
^^^

ntopng registers the `HASSH`_ fingerprints of an host, either when the host initiates or receives an SSH connection,
along with their the number of uses. As explained in the `related Flows section`_, this information can be used to identify
malicious applications or vulnerable SSH versions.

.. _`HASSH`: https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c
.. _`related Flows section`: ../flows/flows.html#ssh-signature

HTTP
^^^^

This page provides information about the HTTP protocol in terms of requests done and responses
received for each HTTP method, together with response codes. Counters are provided both as tables and
pie charts. In the case of virtual host being detected, a badge with the number of virtual hosts detected for
the same IP address is displayed in the host bar and an entry for each virtual server is displayed in a
virtual server table.

.. figure:: ../../../img/web_gui_host_details_http.png
  :align: center
  :alt: Host HTTP View

  The HTTP View of the Host Details Page with Virtual Hosts

.. _Sites:

Sites
^^^^^

.. note::

   This page is only available at lieast with a Pro License.

ntopng can keep track of top visited sites for any monitored local
host. Enabling the tracking of top visited sites requires preference
"Top HTTP Sites" to be set using the ntopng preferences page.

.. figure:: ../../../img/web_gui_visited_sites_preference.png
  :align: center
  :alt: Enabling Visited Sites

  The Preferences Page to Enable Visited Sites

Once the preference has been enabled, this page will start showing
visited websites, which are shown over the two most recent 5-minute
intervals. Newly visited sites are placed under the "Current
Sites". Every 5 minutes ntopng moves the "Current Sites" under "Last 5
Minute Sites", and starts over with a clean "Current Sites".

.. figure:: ../../../img/web_gui_visited_sites.png
  :align: center
  :alt: Host Sites View

  The Sites View of the Host Details Page

Column "Contacts" count the number of time a particular website has
been visited. Every time the host visit a site, the corresponding
"Contacts" counter is increased by one.

.. note::

   This page is only available in the Host Details page menu when
   there is at least one visited website.

.. _Flows:
   
Flows
^^^^^

Flows page lists all active flows that have the selected host as an endpoint. A section of this manual
discuss in greater detail the statistics shown for flows.

.. figure:: ../../../img/web_gui_host_details_flows.png
  :align: center
  :alt: Host HTTP View

  The Flows View of the Host Details Page

SMNP
^^^^

SMNP page provides SNMP information for the selected host with all the standard SNMP traffic metrics.

.. figure:: ../../../img/web_gui_host_details_snmp.png
  :align: center
  :alt: Host SNMP View

  The SMNP View of the Host Details Page

Talkers
^^^^^^^

Talkers page provides top talkers having active flows with selected host. Similarly to the Community
edition dashboard, top talkers are laid out in a Sankey Diagram.

Host Flows
^^^^^^^^^^
.. note::

   This page is only available with an Enterprise License.

The Host Flows page provides an interactive map that shows the currently active flows of the interested host, its peers and protocols.

.. figure:: ../../../img/web_gui_host_details_sankey.png
  :align: center
  :alt: Host Sankey

  The Talks page of the Host Details Page

Geomap
^^^^^^

Geomap page provides an interactive map that shows the selected hosts, its flows, and its
peers. The map is zoomable, both using the mouse rotor or the buttons at the top right corner. Each dot on the map is a host, by hovering the mouse on a dot a tooltip opens and information about the given host are presented.

.. figure:: ../../../img/web_gui_host_details_geo.png
  :align: center
  :alt: Host Geomap View

  The Geomap View of the Host Details Page

Alerts Configuration
^^^^^^^^^^^^^^^^^^^^

Alerts Configuration page enables the user to set custom thresholds on multiple metrics, and to trigger
alerts based on those thresholds. Alerts can be armed, among other metrics, per total bytes, DNS traffic,
P2P traffic or packets, in a fixed time interval. Available time intervals are 1 and 5 minutes, 60 minutes,
and 1 day. Two columns are available for configuration. The first affects only the selected local host,
whereas the second affects all local hosts. Alerts can be configured from the host :ref:`WebUIUserScripts`.

Asset Map
^^^^^^^^^

.. note::

   This page is only available with an Enterprise L License.

.. figure:: ../../../img/web_gui_host_details_asset_map_entry.png
  :align: center
  :alt: Asset Map button

  The Asset Map link on the Host Details Page

The Asset Map is used to understand the assets in a network (DNS, NTP,... servers) and which 'Assets' a specific host uses.
More information can be found at :ref:`Asset Map`.

Statistics
^^^^^^^^^^

Statistics page provides historical traffic statistics for the selected host. The user can choose to filter
statistics on a protocol basis and display data in several formats (e.g., bytes, packets, flows, and so on).

.. figure:: ../../../img/web_gui_host_details_stats.png
  :align: center
  :alt: Host Statistics View

  The Statistics View of the Host Details Page

.. figure:: ../../../img/web_gui_host_details_stats_dropdown.png
  :align: center
  :alt: Host Statistics Dropdown

  The Dropdown menu in The Statistics View of the Host Details Page

Periodicity Map
^^^^^^^^^^^^^^^

.. note::

   This page is only available with an Enterprise L License.

.. figure:: ../../../img/web_gui_host_details_periodicity_map_entry.png
  :align: center
  :alt: Periodicity Map button

  The Periodicity Map link on the Host Details Page

The Periodicity Map is used to understand the local communication between hosts in a network.
More information can be found at :ref:`Periodicity Map`.

Service Map
^^^^^^^^^^^

.. note::

   This page is only available with an Enterprise L License.

.. figure:: ../../../img/web_gui_host_details_service_map_entry.png
  :align: center
  :alt: Service Map button

  The Service Map link on the Host Details Page

The Service Map is used to understand the local communication between hosts in a network.
More information can be found at :ref:`Service Map`.

Historical Flow
^^^^^^^^^^^^^^^

.. note::

   This page is only available with an Enterprise License and only if ClickHouse is enabled

.. figure:: ../../../img/web_gui_host_details_historical_flow_entry.png
  :align: center
  :alt: Historical Flow button

  The Historical Flow link on the Host Details Page

The Historical Flow is used to understand the local communication between hosts in a network.
More information can be found at :ref:`Historical Flow Explorer`.

Host Configuration
^^^^^^^^^^^^^^^^^^

.. figure:: ../../../img/web_gui_host_configuration.png
  :align: center
  :alt: Host Configuration

  The Host Configuration on the Host Details Page

In this page a user is able to give an Alias to an Host (an alternative name for an host that's going to be used in all ntopng), give a description to an host, 
assign this host to an host pool or hide this host from the Top Talkers computation.

MAC Addresses
-------------

The MAC Addresses page lists the network cards (MAC addresses) that ntopng sees on the
selected network interface. Devices that are idle are not listed.

For each MAC address you can see:

- the MAC address
- its manufacturer, and the model when ntopng recognizes it
- the device type (for example laptop, phone, printer), with an icon
- its name; when it has none, the first host (IP address) that uses it and how many other
  hosts use it
- how many hosts use it and how many ARP packets (the messages that link an IP address to
  a MAC address) it sent and received
- how long ago it was first seen
- how much traffic it sends and receives, its current speed and its total traffic

On nEdge a *Location* column also shows whether the device is on the LAN or on the WAN.

Use the filters above the table to show only the MAC addresses that sent traffic (*Source
Only*), or the ones of a manufacturer or of a device type. You can also click a manufacturer,
a device type or a location in the table to filter by it. *Clear filters* removes all the
filters.

To open all the details of a MAC address, click the button in the *Actions* column, or the
small arrow icon next to the MAC address. The menu next to the button also lists the hosts
that use that MAC address.
