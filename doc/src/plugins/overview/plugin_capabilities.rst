Plugin Capabilities
-------------------

By means of plugins, ntopng can execute actions at regular intervals
of time, or when it detects a certain condition. Plugins can also be
used to create custom pages and add them to the ntopng menu, and even
to create timeseries of certain metrics of interest.

All plugin capabilities are briefly summarized below.

Alerts
~~~~~~

Plugins allow the generation of custom alerts. For example, one can
create an alert when it detects a certain host has too many TCP
retransmissions, or then the traffic towards a certain network drops
below a critical level. Similarly, one can create an alert when a
certain flow is using a suspicious port, or an invalid TLS
certificate.

Flow Statuses
~~~~~~~~~~~~~

By means of plugins, one can assign statuses to flows. Think
to a status as a sort of label, a tag which can be attached to flows
having certain features. So for example one can assign status
:code:`high_latency` to Remote Desktop flows with a latency above
250ms. Similarly, a status :code:`suspicious_port` can be assigned to
HTTP flows using a server port different from port 80. These are just
a couple of examples and actually the set of flow features one can use and
combine to assign a status is almost unlimited. Flow statuses can be
combined with alerts to instruct ntopng to trigger an alert as soon as
a certain flow status is detected.

Creating Custom Pages
~~~~~~~~~~~~~~~~~~~~~

Creating custom pages may be useful to users who want to extend
ntopng functionalities. For example, by means of custom pages, one can
create a TLS or MySQL ping to test and monitor the status of certain
critical services, and also chart the results. Custom pages can also
be added to the ntopng menu to allow quick access.

Writing Timeseries
~~~~~~~~~~~~~~~~~~

Using plugins, one can create and write timeseries for any custom
metric of interest. One can chart a particular metric for local hosts
(e.g., the number SYNs received), networks, and so on. ntopng charting
library can then be used to visualize created timeseries.

