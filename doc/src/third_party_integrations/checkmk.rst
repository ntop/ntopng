.. _CheckmkIntegration:

Checkmk Integration
###################

ntopng seamlessly integrates with Checkmk, a popular open-source infrastructure monitoring tool, providing comprehensive traffic visibility alongside traditional IT infrastructure monitoring. This integration combines the big picture perspective of IT infrastructure monitoring with in-depth network usage information from ntopng.

Overview
========

The integration makes data from talkers and listeners detected by ntopng directly available in Checkmk. It adds network flow information from ntopng to respective hosts in Checkmk, consolidating all data into one solution with multiple dashboards and graphing options. This enables faster root cause analysis with less effort.

By leveraging ntopng's REST API, the integration eliminates the need to jump between ntopng and your IT infrastructure monitoring tool. Network flow information from ntopng is automatically allocated to hosts in Checkmk monitoring, combining information gathered by Checkmk with the most important traffic information from ntopng.

Use Cases
=========

The integration offers several views and dashboards in Checkmk to support various monitoring scenarios:

- Analyze hosts, applications, or protocols communicating with each other
- Identify possible bottlenecks or anomalies
- Identify 'top talkers' and 'top listeners' in your network
- View network usage per host and other detailed metrics
- Import notifications from ntopng and combine them with infrastructure alerting

Prerequisites
=============

Before setting up the integration, ensure you have the correct versions:

**ntopng Requirements:**
- Professional or Enterprise version 4.2 or higher
- REST API V1 support (available from version 4.2 onwards)

**Checkmk Requirements:**
- Enterprise Edition version 2.0 or higher
- ntopng integration add-on (payable)

.. note::
   A free trial of Checkmk Enterprise Edition is available, which includes all features but is limited to 25 hosts after 30 days.

Setup
=====

Preparation: Configure ntopng Parameters
-----------------------------------------

Checkmk requires a user account in ntopng to access data. You can limit access by using an ntopng user with restricted privileges, depending on your environment and which network interfaces you want to share with Checkmk.

For this tutorial, we'll use the simplest option: an ntopng user with admin access that gives Checkmk full access to all interfaces.

You'll need:
- ntopng username and password
- ntopng server hostname and TCP port
- Network connectivity from Checkmk server to ntopng server

Step 1: Configure ntopng User in Checkmk
-----------------------------------------

1. Open your Checkmk site and navigate to **Setup → General → Global settings**
2. Click on **Ntopng (chargeable add-on)**
3. Click on **Ntopng Connection Parameters (chargeable add-on)**
4. Configure the following parameters:

   - **Host address**: hostname of your ntopng server (must be DNS resolvable for TLS)
   - **Port number**: TCP port for ntopng (default: 3000 for HTTP, 3001 for HTTPS)
   - **Protocol**: Choose HTTPS for security (check SSL validation disable for self-signed certificates)
   - **User account for authentication**: ntopng username for data access
   - **ntopng username acquire data for**: Select appropriate option based on your username setup

Step 2: Add ntopng Username to Checkmk User
--------------------------------------------

If using different usernames for Checkmk and ntopng accounts:

1. Navigate to **Setup → Users**
2. Select the properties of your Checkmk user by clicking the pencil icon
3. Add the ntopng username in the **ntopng Username** field under **Identity**
4. Click **Save**
5. Activate changes by clicking the yellow exclamation point and selecting **Activate on selected sites**

.. note::
   Skip this step if using identical usernames in both systems.

Step 3: Verify Integration
--------------------------

1. Click **Monitor** in the sidebar
2. Look for a new topic named **Network statistics**
3. This confirms the integration is working correctly

Step 4: Add Hosts to Checkmk
-----------------------------

Unlike network flow monitoring, infrastructure monitoring requires proactive host addition. If your Checkmk environment already contains communicating network hosts, skip this step.

For new Checkmk installations:

1. Navigate to **Setup → Hosts**
2. Click **Add host**
3. Configure hostname (add IP address if not DNS resolvable)
4. Under **Monitoring Agents**, configure appropriate monitoring method (e.g., SNMP)
5. Set credentials if required
6. Click **Save & go to service configuration**
7. Review automatically discovered services
8. Click **Fix all** to add detected services
9. Activate changes via the yellow exclamation point

Step 5: Monitor ntopng Hosts in Checkmk
----------------------------------------

1. Navigate to **Monitor → Network statistics → Ntop Hosts**
2. View overview of all hosts monitored in both Checkmk and ntopng
3. Access detailed host information via **Ntopng integration of this host** in the action menu
4. Use various tabs for different perspectives:
   - **Host**: Basic information and summary
   - Additional tabs for specific network insights
5. Click **View data in ntopng** to jump directly to the host in ntopng

Alert Integration
=================

ntopng can export traffic alerts to the Checkmk Event Console, extending monitoring capabilities beyond basic metrics.

Configuration Process:

1. **In ntopng**: Configure Endpoints and Recipients under **Alerts → Notifications**
2. **In Checkmk**: Set up Service Levels and Event Console rules
3. **Result**: Receive ntopng notifications in Checkmk Event Console

For detailed alert integration setup, refer to: `How to Export ntopng Alarms to Checkmk Event Console <https://www.ntop.org/howto-export-ntopng-alarms-to-checkmk-event-console/>`_

Additional Resources
====================

For more comprehensive information:

- `Using ntopng with Checkmk - Complete Tutorial <https://www.ntop.org/using-ntopng-with-checkmk-a-tutorial/>`_
- Checkmk User Guide - ntop integration chapter
- Checkmk Beginner's Guide
- Checkmk Event Console Documentation

.. warning::
   The integration requires proper network connectivity between Checkmk and ntopng servers. Ensure firewall rules allow communication on the configured ports.

.. tip::
   Start with a limited number of hosts to test the integration before scaling to your entire infrastructure.