System Behavioural Checks
#########################

System checks are designed to spot ntopng problems and thus make sure the application is healthy.

____________________

**Periodic Activity Not Executed**
~~~~~~~~~~~~~~~~~~~~~~
Checks for periodic activity execution.

The system sends an alert when a periodic activity is queuing and is not getting executed.

The alert is sent when the worker threads are busy.

*Category: Internals*

*Enabled by Default*

____________________


**Slow Periodic Activity**
~~~~~~~~~~~~~~~~~~~~~~
Checks for slow periodic activity.

A periodic activity is taking time to start the execution.

The alert is sent to notify that a periodic activity takes too long.

*Category: Internals*

*Enabled by Default*

____________________

**System Alerts Drops**
~~~~~~~~~~~~~~~~~~~~~~
Checks for a system alerts drops.

Too many alerts are generated in a short period of time, this may cause the system dropping the alerts.

The alert is sent when there is no room in the internal alerts queue and the alerts are dropped.

*Category: Internals*

*Enabled by Default*

**IDS Log**
~~~~~~~~~~~~~~~~~~~~~~
Checks for Intrusion Detection and Prevention logs.

Ntopng notifies when a host has been added or removed from the jailed hosts pool.

The Alert is sent when unusual logged events are detected.

*Category: Internals*

*Not Enabled by Default*

