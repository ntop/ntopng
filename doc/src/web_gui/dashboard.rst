Dashboard
#########
Dashboard is a dynamic page and provides an updated snapshot of the current traffic for the selected interface or interface view being monitored by ntopng. Community and Professional version have two different dashboards.

Dashboard in the Community Version
----------------------------------
The dashboard provides information about Talkers, Hosts, Ports, Applications, ASNs, and Senders. Information can be selected from the top menu. Each item is discussed below.

.. figure:: ../img/web_gui_dashboard_community_top_menu.png
  :align: center
  :alt: The Top Menu for the Dashboard

  The Top Menu for the Dashboard


Talkers
^^^^^^^
The default dashboard page is a Sankey diagram of Top Flow Talkers

.. figure:: ../img/web_gui_dashboard_sankey.png
  :align: center
  :alt: The Sankey Diagram of Top Flow Talkers

  The Sankey Diagram of Top Flow Talkers

The Sankey diagram displays hosts currently active on the monitored interface or interface view. Host pairs are joined together by colored bars representing flows. The client host is always placed in the left edge of the bar. Similarly, the server is placed on the right. Bar width is proportional to the amount of traffic exchanged. The wider the bar, the higher the traffic exchanged between the corresponding pair of hosts.

By default, the diagram is updated every 5 seconds. Refresh frequency can be set or disabled from the dropdown menu shown right below the diagram.
Host and flow information shown in the Sankey is interactive. Indeed, both host names (IP addresses) as well as flows are clickable.

.. figure:: ../img/web_gui_dashboard_sankey_refresh_settings.png
  :align: center
  :alt: Diagram Refresh Settings

  Diagram Refresh Settings

  A double-click on any host name redirects the user the 'Host Details' page, that contains a great deal of host-related information. This page will be discussed later in the manual.

Similarly, a double-click on any bar representing a flow redirects the user to the 'Hosts Comparison' page. Hosts can be pairwise compared in terms of Applications, Layer-4 Protocols, and Ports. A pie chart of exchanged traffic can be shown as well.
Below is shown an Application comparison between two hosts. The diagram shows that both hosts on the left have used DNS services (on the right). It is also possible to visually spot behaviors and trends. For example it is possible to see that jake.unipi.it is much more prone to use Google’s DNS than the other host.

.. figure:: ../img/web_gui_dashboard_sankey_pairwise_host_comparison.png
  :align: center
  :alt: Pairwise Host Comparison

  Pairwise Host Comparison

Hosts
^^^^^
Hosts View provides a pie chart representation of the captured traffic. Aggregation is done on a per-host basis. Similarly to the Sankey Diagram discussed above, any host name (or non-resolved IP address) shown can be double-clicked to visit the corresponding ‘Host Details’ page.

The pie chart is refreshed automatically.

.. figure:: ../img/web_gui_dashboard_community_pie_chart_top_hosts.png
  :align: center
  :alt: Pie Chart of Top Hosts

  Pie Chart of Top Hosts

Ports
^^^^^
Ports view provides two separated pie charts with the most used ports, both for clients and for servers. Each pie chart provides statistics for client ports and server ports.

.. figure:: ../img/web_gui_dashboard_community_pie_chart_top_ports.png
  :align: center
  :alt: Pie Chart of Top Client and Server Ports

  Pie Chart of Top Client and Server Ports

Any port number shown can be double-clicked to visit the 'Active Flows' page. This page lists all the currently active flows such that client or server port matches the one clicked.

Applications
^^^^^^^^^^^^
Application View provides another pie chart that represents a view of the bandwidth usage divided per application protocol. Protocol identification is done through ntopn nDPI engine. Protocols that cannot be identified are marked as Unknown.

.. figure:: ../img/web_gui_dashboard_community_pie_chart_top_applications.png
  :align: center
  :alt: Pie Chart of Top Applications

  Pie Chart of Top Applications

In the same manner as for previous view, application names are clickable to be redirected to a page with more detailed information on application.

Dashboard in the Professional Version
-------------------------------------
