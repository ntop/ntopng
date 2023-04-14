.. _WebGuiFlows:

Flows
#####

Live
----

The ‘Flows’ entry in the top toolbar can be selected to visualize realtime traffic information on the currently
active flows. A flow can be thought of as a logical, bi-directional communication channel between two
hosts [1]_. Multiple simultaneous flows can exist between the same pair of hosts.

.. figure:: ../img/web_gui_flows_active.png
  :align: center
  :alt: Active Flows

  Active Flows Page

Flows are uniquely identified via a 5-tuple composed of:

- Source and destination IP address
- Source and destination port
- Layer-4 protocol

Each flow is shown as a row entry in the flows table. Flows are sortable by application using the rightmost
dropdown menu at the top right edge of the table. Similarly, the other dropdown menu enables the user
to choose the number of flows displayed on each page.

Flows have multiple information fields, namely, Application, Layer-4 Protocol, Client and Server hosts,
Duration, Client and Server Breakdown, Current Throughput, Total Bytes, and Additional Information.
Information fields are briefly discussed below.

Detailed Flow Information
^^^^^^^^^^^^^^^^^^^^^^^^^

By clicking the lens image at the beginning of the flow, it's possible to jump to the detailed flow information. Here all the information ntopng has about the flow, are going to be displayed.

.. figure:: ../img/web_gui_flows_details.png
  :align: center
  :alt: Flow Details

  Flow Details Page


Application
^^^^^^^^^^^

Application is the Layer-7 program which is exchanging data through the flow. This is the piece of
software that lays closest to the end user. Examples of Applications are Skype, Redis, HTTP, and Bit
Torrent. Layer-7 applications are detected by the NTOP open source Deep Packet Inspection (DPI) engine
named nDPI [2]_. In case application detection fails, ntopng marks the flow as ‘Unknown’. If the detection
succeeds, the application name and an informative icon are shown.

Here is a list of possible informative icons:

  - The lock icon tells that the protocol carries information in a secure way (e.g. via SSL)
  - The thumb-up icons tells that the protocol is generally not harmful for network performance
  - The thumb-down icons tells that the protocol is generally harmful for network performance
  - The smile face tells that the protocol is generally used for user entertainment
  - The yellow triangle indicates a possible problem on the flow. By clicking a flow details it's possible to see what the reported problem is (e.g. flow with low goodput)

The application name can be clicked to see all hosts generating traffic for the application.

Layer-4 Protocol (L4 Proto)
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The layer-4 protocol is the one used at the transport level. Most common transport protocol are the
reliable Transmission Control Protocol (TCP) and the best-effort User Datagram Protocol (UDP).

Client
^^^^^^

This field contains host and port information regarding the client endpoint of the flow. An host is
considered a client if it is the initiator of the flow. Information is shown as host:port and both information
are clickable. If the host has a public IP address, ntopng also shows the country flag for that client [3]_ . A blue
flag is drawn when the host is the ntopng host.

Server
^^^^^^

Similarly to the client, this field contains information regarding the server endpoint of the flow. An host is
considered a server if it is not the initiator of the flow. We refer the reader to the previous paragraph for a
detailed description.

Duration
^^^^^^^^

This is the amount of time that has elapsed since the flow was opened by the client.

Breakdown
^^^^^^^^^

Flows are bi-directional, in the sense that traffic flows both from the server to the client and from the client
to the server. This coloured bar gives and indication on the amount of traffic exchanged in each of the two
directions. Client to server traffic in shown in orange, while server to client in blue.

Actual Throughput
^^^^^^^^^^^^^^^^^

The throughput is computed periodically (the refresh time is a few seconds).

Total Bytes
^^^^^^^^^^^

The amount of traffic exchanged thought the flow. This total value is the sum of traffic exchanged in each
of the two directions (client to server and server to client).

TLS Information
^^^^^^^^^^^^^^^

ntopng provides detailed information on TLS flows:

.. figure:: ../img/web_gui_flows_tls_information.png
  :align: center
  :alt: TLS information

- The TLS certificate requested by the client and the server names returned by the server
- The TLS certificate validity time frame
- Client and server `JA3`_ signatures, which represent a fingerprint of the most relevant
  information in the TLS handshake. By clicking on the signature it is possible to manually
  check if the signature corresponds to a known malware into the `abuse.ch database`_.
- The Client `TLS ALPN`_, which contains the list of application protocols provided
  by the client during the TLS handshake
- The supported TLS protocols of the client

This information is very valuable in identifying potential threats on the encrypted traffic,
which include but are not limited to:

- Malicious clients/server (by matching the JA3 signature)
- Expired TLS certificates
- Unsecure TLS protocols in use
- MITM TLS attacks

ntopng already reports such events with specialized alerts (the available alerts
depend on the ntopng version used). For an in depth discussion on the challenges with encrypted traffic and how
the metadata can help in identifying network threats, check out the related ntop
`blog post`_ and related posts.

SSH Signature
^^^^^^^^^^^^^

In a similar way to the JA3 TLS signature, `HASSH`_ is a fingerprint on the SSH handshake.
ntopng generates the HASSH fingerprint of both the client and the server hosts of the flow.
ntopng also extracts and visualizes the SSH application banner which usually reports the
name and version of the SSH client/server application used.

This information can be used to identify outdated and vulnerable programs, which
undermine the hosts security. Moreover, the HASSH fingerprint can be matched against
known malware signatures to identify known threats.

.. _`HASSH`: https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c

DNS Signature
^^^^^^^^^^^^^

ntopng also extracts and visualizes information regarding DNS application.
It reports, in the following order, the DNS query type, the DNS query error and DNS query,
following the standard classification (`RFC1035`_).

.. figure:: ../img/web_gui_flows_dns_information.png
  :align: center
  :alt: DNS information

Info
^^^^

Extra information nDPI is able to extract from the detected flow is made available in this field. This field
may include URLs, traffic profiles (in the Professional Version), contents of DNS requests, and so on.

.. [1] Actually, flows may also exist between a host and a multicast group, as well as a broadcast domain.
.. [2] https://github.com/ntop/nDPI
.. [3] These data are based on MaxMind databases.

Issues
^^^^^^

A flow could have some issues (reported in the :ref:`BasicConceptAlerts`).
All the issues of the flow are reported in the Detailed Flow Information page.

.. figure:: ../img/web_gui_flows_issues_information.png
  :align: center
  :alt: DNS information

.. _`JA3`: https://github.com/salesforce/ja3
.. _`TLS ALPN`: https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation
.. _`blog post`: https://www.ntop.org/ndpi/effective-tls-fingerprinting-beyond-ja3
.. _`abuse.ch database`: https://sslbl.abuse.ch/ja3-fingerprints
.. _`RFC1035`: https://datatracker.ietf.org/doc/html/rfc1035



Historical Flows Explorer
-------------------------

When ClickHouse is enabled, an historical flows explorer becomes available in the ntopng web GUI.
This page is used to navigate throw the flows seen and stored by ntopng.

.. note::

   ClickHouse support including the Historical Flows Explorer is only available in ntopng Enterprise M or above.


The explorer is available from the left sidebar, under the Flows section.

.. figure:: ../img/clickhouse_flow_explorer.png
  :align: center
  :alt: Historical Flows Explorer

  Historical Flows Explorer

It is possible, like for the Alerts Page, to navigate throw the flows by filtering the results.
Multiple filters are available by clicking the various results (e.g. The host `develv5`, to investigate its activities) or by clicking the `+` symbol in the right upper part of the GUI and selecting the wanted filter.

See :ref:`Historical Flow Explorer` for more information.


Analysis
--------

.. figure:: ../img/live_flows_nav_bar.png
  :align: center
  :alt: Live Flows navigation bar

  Live Flows navigation bar

By switching tab and clicking the analysis entry, an other view of the flows is going to be displayed, showing the informations aggregated.

Application Protocol Criteria
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. figure:: ../img/live_flows_analysis_app_criteria.png
  :align: center
  :alt: Live Flows Analysis Application Criteria

From here it's possible to understand the amount of flows, traffic and hosts having a particular application protocol in order to understand easly if there is some flow (using some protocol) that shouldn't be there.
By clicking on the icon at the left of the protocol, the user is going to jump to the live flow page with the selected protocol filtered.

Client Criteria
^^^^^^^^^^^^^^^

.. figure:: ../img/live_flows_analysis_client_criteria.png
  :align: center
  :alt: Live Flows Analysis Client Criteria

Using the aggregation criteria "Client" it's possible to aggregate the live flows by the clients and understand the amount of flows, traffic and hosts having a particular client.
By clicking on the icon at the left of the client, the user is going to jump to the live flow page with the selected client filtered. 
Instead, by clicking on the client, the user is going to jump to the host_details page of the selected client.

Server Criteria
^^^^^^^^^^^^^^^

.. figure:: ../img/live_flows_analysis_server_criteria.png
  :align: center
  :alt: Live Flows Analysis Server Criteria

Using the aggregation criteria "Server" it's possible to aggregate the live flows by the servers and understand the amount of flows, traffic and hosts having a particular server.
By clicking on the icon at the left of the server, the user is going to jump to the live flow page with the selected server filtered.
Instead, by clicking on the server, the user is going to jump to the host_details page of the selected server.

.. note::

  The following aggregation criteria are available only from Enterprise M license or superior.

Client / Server Criteria
^^^^^^^^^^^^^^^^^^^^^^^^

.. figure:: ../img/live_flows_analysis_client_server_criteria.png
  :align: center
  :alt: Live Flows Analysis Client / Server Criteria

Using the aggregation criteria "Client / Server" it's possible to aggregate the live flows by the couple client-server and understand the amount of flows, traffic and hosts having a particular client-server.
By clicking on the icon at the left of the client, the user is going to jump to the live flow page with the selected client and server filtered.
Instead, by clicking on the client or on the server, the user is going to jump to the host_details page of the selected client or server.

App. Proto / Client / Server Criteria
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. figure:: ../img/live_flows_analysis_app_client_server_criteria.png
  :align: center
  :alt: Live Flows Analysis App. Proto / Client / Server Criteria

Using the aggregation criteria "App. Proto / Client / Server" it's possible to aggregate the live flows by the triple application protocol, client and server and understand the amount of flows, traffic and hosts having a particular app. proto-client-server.
By clicking on the icon at the left of the client, the user is going to jump to the live flow page with the selected application protocol, client and server filtered.
Instead, by clicking on the client or on the server, the user is going to jump to the host_details page of the selected client or server.

Info Criteria
^^^^^^^^^^^^^

.. figure:: ../img/live_flows_analysis_info_criteria.png
  :align: center
  :alt: Live Flows Analysis Info Criteria

Using the aggregation criteria "Info" it's possible to aggregate the live flows by the flow's info and understand the amount of flows, traffic and hosts having a particular flow's info.
By clicking on the icon at the left of the info column, the user is going to jump to the live flow page with the selected flow's info filtered.
