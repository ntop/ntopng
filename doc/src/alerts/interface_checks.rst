Interface Behavioural Checks
############################

These checks are performed per network interface monitored by ntopng.

____________________


**Alerts Drops**
~~~~~~~~~~~~~~~~

Checks for dropped alerts.

The alerts could be dropped when too many are queued/generated.

The alert is sent when the system drops the alert.

*Category: Internals*

*Enabled by Default*


**DHCP Storm**
~~~~~~~~~~~~~~

Checks for DHCP flooding.

DHCP storm occurs when DHCP router gets too many packets requests in a minute - by blocking totally the router functioning.

The alert is triggered when DHCP storm is detected.

*Category: Cybersecurity*

*Enabled by Default*


**Ghost Networks**
~~~~~~~~~~~~~~~~~~~~~~

Checks for ghost networks.

There are many reasons why the ghost network may appear - starting from misconfiguration and ending with malicious users who put devices on the network believing not to be discovered.

The alert is sent when the unknown network is discovered.

*Category: Cybersecurity*

*Enabled by Default*

**Idle Hash Table Entries**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for Idle Entries.

Trigger an alert when the percentage of idle entries in the hash table over the total number of entries exceeds the threshold.

*Category: Internals*

*Enabled by Default*


**No Traffic Activity**
~~~~~~~~~~~~~~~~~~~~~~~

Checks for activities on the interface.

There could be no traffic because of misconfigurations or because of the mirror network link that has gone down.

The alert is sent when no activity on the interface is noticed.

*Category: Internals*

*Enabled by Default*

**Packet Drops**
~~~~~~~~~~~~~~~~

Checks for dropped packets.

The packets could be dropped when too many are analyzed.

The alert is sent when the system drops packets.

*Category: Internals*

*Enabled by Default*


**Periodic Activity Not Executed**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for periodic activity.

Periodic activity is not executed since all the worker threads are busy will be buffered until a worker threads are available once again

Alert is sent when the periodic activity hasn't been executed.


*Category: Internals*

*Enabled by Default*


**Slow Periodic Activity**
~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for slow execution of periodic activity.

A bug is causing a periodic activity to take more than its max duration to complete.


Alert is sent when periodic activity is taking too long to execute. 

*Category: Internals*

*Enabled by Default*


**Throughput**
~~~~~~~~~~~~~~~~~~~~

Checks for throughput rate.

When the system throughput (https://en.wikipedia.org/wiki/Network_throughput) rate exceeds a pre-configured threshold of the maximum allowed throughput rate.

The alert is sent when the throughput exceeds threshhold.

*Category: Network*

*Enabled by Default


**Unexpected Application Behaviour**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for unexpected app behaviour.

Unexpected behaviour in applications could be an indicator of bugs in the code that causes an unusual attitude or incorrect functioning of an app.

Alert is sent when unusual app behaviour is detected.

*Category: Network*

*Enabled by Default*


**Unexpected ASN Behaviour**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for ASN Behaviour.

Unexpected behavior is identified in traffic coming from one of the subnets of the ASN = Autonomous System Number (https://en.wikipedia.org/wiki/Autonomous_system_(Internet))

The alert is sent when unexpected behaviour is seen in ASN.

*Category: Cybersecurity*

*Not Enabled by Default*


**Unexpected Device Connected/Disconnected**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Check for MAC addresses.

An alert is triggered whenever an unexpected MAC address connects or disconnects form an Interface. After enabling the alert, a new page, called `Devices Exclusion` (more info can be found `here <../advanced_features/devices_exclusion.html>`_) is going to be available in the `Settings` menu. 

By jumping there, users are able to configure denied/allowed MAC addresses (unexpected/expected MAC addresses). When a denied or non accounted MAC address connects to the Interface a new Engaged alert is going to be triggered, that is going to be released when the unexpected MAC address is going to disconnect from the Interface or when allowed.  

*Category: Network*

*License: Pro*

*Disabled by Default*


**Unexpected Network Behaviour**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for Unexpected Behaviour.

Network behavior anomaly detection is focused on networks for abnormal behavior in order to detect threats or flaws.
 
Alert is triggered when unexpected behaviour comes from the specific network.

*Category: Cybersecurity*

*Not Enabled by Default*  


**Unexpected Score Behaviour**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for Unexpected Behaviour.

Score behavior anomaly detection is focused on score for abnormal behavior in order to detect threats or flaws.
 
Alert is triggered when unexpected behaviour comes from the interface.

*Category: Cybersecurity*

*Not Enabled by Default*  


**Unexpected Traffic Behaviour**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for Unexpected Behaviour.

Traffic behavior anomaly detection is focused on the interface for abnormal behavior in order to detect threats or flaws.
 
Alert is triggered when unexpected behaviour comes from the interface.

*Category: Cybersecurity*

*Not Enabled by Default*  
