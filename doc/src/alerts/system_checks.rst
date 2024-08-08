System Behavioural Checks
#########################

System checks are designed to spot ntopng problems and thus make sure the application is healthy.

____________________


**Exporters Limit Exceeded**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for a the number of exporters.

Each ntopng license supports up to a specific number of exporters.

The alert is sent when there are more exporters than the number supported by the license.

*Interface: Packet & ZMQ*

*Category: Internals*

*Enabled by Default*


**Intrusion Detection and Prevention Log**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for Intrusion Detection and Prevention logs.

Ntopng notifies when a host has been added or removed from the jailed hosts pool.

The Alert is sent when unusual logged events are detected.

*Interface: Packet & ZMQ*

*Category: Internals*

*Not Enabled by Default*


**Periodic Activity Not Executed**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for periodic activity execution.

The system sends an alert when a periodic activity is queuing and is not getting executed.

The alert is sent when the worker threads are busy.

*Interface: Packet & ZMQ*

*Category: Internals*

*Enabled by Default*


**Slow Periodic Activity**
~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for slow periodic activity.

A periodic activity is taking time to start the execution.

The alert is sent to notify that a periodic activity takes too long.

*Interface: Packet & ZMQ*

*Category: Internals*

*Enabled by Default*


**System Alerts Drops**
~~~~~~~~~~~~~~~~~~~~~~~
Checks for a system alerts drops.

Too many alerts are generated in a short period of time, this may cause the system dropping the alerts.

The alert is sent when there is no room in the internal alerts queue and the alerts are dropped.

*Interface: Packet & ZMQ*

*Category: Internals*

*Enabled by Default*


**System Error**
~~~~~~~~~~~~~~~~
Checks for a system errors.

Trigger an alert when a system error (ntopng failure) is detected.

*Interface: Packet & ZMQ*

*Category: Internals*

*Enabled by Default*

