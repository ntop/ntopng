Interface Behavioural Checks
############################

These checks are performed per network interface monitored by ntopng.

____________________

**Ghost Networks**
~~~~~~~~~~~~~~~~~~~~~~

Checks for ghost networks.

There are many reasons why the ghost network may appear - starting from misconfiguration and ending with malicious users who put devices on the network believing not to be discovered.

The alert is sent when the unknown network is discovered.

*Category: Cybersecurity*

*Enabled by Default*

**Idle Hash Table Entries Alert**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~






**Interface Alerts Drops**
~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for dropped alerts.

The alerts could be dropped when too many are queued/generated.

The alert is sent when the system drops the alert.

*Category: Cybersecurity*

*Enabled by Default*


**No activity on interface**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for activities on the interface.

There could be no traffic because of misconfigurations or because of the mirror network link that has gone down.

The alert is sent when no activity on the interface is noticed.

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


**Throughput Alert**
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



**Unexpected Device Connected**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for unexpected device.

A random device without an allowed MAC address connected to the network.

Alert is sent when a unexpected device connected.

*Category: Network*

*Not Enabled by Default*



**Unexpected Network Behaviour**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for Unexpected Behaviour.

Network behavior anomaly detection is focused on networks for abnormal behavior in order to detect threats or flaws.
 
Alert is triggered when unexpected behaviour comes from the specific network.

*Category: Cybersecurity*

*Not Enabled by Default*


**DHCP Storm**
~~~~~~~~~~~~~~

Checks for DHCP flooding.

DHCP storm occurs when DHCP router gets too many packets requests in a minute - by blocking totally the router functioning.

The alert is triggered when DHCP storm is detected.

*Category: Cybersecurity*

*Enabled by Default*


**DHCP Starvation**
~~~~~~~~~~~~~~~~~~~

Checks for DHCP starvation.


DHCP starvation attacks and DHCP spoofing. In DHCP starvation attacks, an attacker floods the DHCP server with DHCP requests to use up all the available IP addresses.The “starved” DHCP server will not respond to new DHCP requests until a new address becomes available.


Ntopng sends an alert in case DHCP starvation occurs.

*Category: Cybersecurity*

*Enabled by Default*


**Unexpected Device Connected/Disconnected**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Check for MAC addresses.

An alert is triggered whenever an unexpected MAC address connects or disconnects form an Interface. After enabling the alert, a new page, called `Devices Exclusion` (more info can be found `here <../advanced_features/devices_exclusion.html>`_) is going to available in the `Settings` menù. 

By jumping there, users are able to configure denied/allowed MAC addresses (unexpected/expected MAC addresses). When a denied or non accounted MAC address connects to the Interface a new Engaged alert is going to be triggered, that is going to be released when the unexpected MAC address is going to disconnect from the Interface or when allowed.  

*Category: Network*

*License: Pro*

*Disabled by Default*
