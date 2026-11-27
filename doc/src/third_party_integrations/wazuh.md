---
title: "Wazuh Integration"
description: "ntopng integrates with Wazuh, an open-source security platform that provides threat detection, integrity monitoring, incident response, and compliance..."
outline: [2, 3]
lastUpdated: 2026-11-24T15:23:43+01:00
---

<a id="wazuhintegration"></a>

# Wazuh Integration {#wazuh-integration}

ntopng integrates with [Wazuh](https://wazuh.com), an open-source security platform that provides threat detection, integrity monitoring, incident response, and compliance capabilities. This integration enriches the ntopng asset inventory by merging endpoint security information, collected by Wazuh agents, directly into ntopng host assets, giving operators a unified view of both network traffic and host security posture.
Currently ntopng uses Wazuh for both collecting Wazuh-generated alerts, and accessing the Wazuh endpoint to fetch information about known assets.

::: info
In order to use Wazuh you need to use an Enterprise edition of ntopng and enable ClickHouse for storing data persistently.
:::

In order to enable Wazuh you need to

- Open ntopng and navigate to **Settings → Preferences → External Integrations → Wazuh**

- Enable Wazuh and fill in the following fields:

  > - **Wazuh URL**: The base URL of the Wazuh Manager API, including the protocol and port (e.g. `https://WAZUH_HOST:55000`). Note that if your Wazuh server is accessed over https without a valid certificate (e.g. a self-signed certificate), you need to start ntopng using --insecure.
  > - **Username**: The Wazuh user account that ntopng will use to authenticate against the API (Usually wazuh-wui)
  > - **Password**: The password for the above account

![Wazuh Preferences](../img/wazuh_prefs.png)

## Wazuh Alerts Collection {#wazuh-alerts-collection}

The Wazuh manager collects raw security events and logs from the endpoints that run a local wazuh agent. These alerts are useful for correlating them with network events produced by ntopng. Alerts are exported periodically by the Wazuh manager to ntopng via redis using filebeats. The trick is to export Wazuh collected alerts stored on /var/ossec/logs/alerts/alerts.json and deliver them to the remote ntopng redis instance via filebeat.

## Configuration {#configuration}

You can do that as follows:

- Duplicate the filebeat systemd service and name it `filebeat-ntop`
- Create /etc/filebeat-ntop/filebeat.yml and in the filebeat.inputs section <https://www.elastic.co/docs/reference/beats/filebeat/configuration-filebeat-options> add something like

```bash
- type: filestream
   id: wazuh-ntop
   paths:
   - /var/ossec/logs/alerts/alerts.json
output.redis:
 hosts: ["ntop.remote.host"]
 key: "filebeat"
 db: 0
 timeout: 5
   #output.console:
   #  pretty: true
seccomp:
 default_action: allow   syscalls:
 - action: allow
   names:
   - rseq
logging.level: info
logging.to_files: true
logging.files:
 path: /var/log/filebeat-ntop
 name: filebeat
```

Please note that:

- you need to replace ntop.remote.host with the hostname or IP address of the host where ntopng (and the redis instance used by ntopng) is running.
- the redis port (6379/tcp) need to be open and reachable to the Wazuh manager host that has to deliver alerts on the remote queue.

Done this you can find Wazuh alert in the left sidebar from hich you can access the Wazuh pages

![Wazuh Alerts](../img/wazuh_alerts.png)

During the ntop installation, some default rules are installed in order to have a ready-to-go configuration

![Wazuh Alert Rules](../img/wazuh_alert_rules.png)

You can edit a rule

![Wazuh Rule Edit](../img/wazuh_edit_rule.png)

specifying parameters such as

- Priority: it specified the rule evaluation order (lower first)
- Minumum Level: the rule has no effect on alerts with level less than the specified valie
- Groups: if empty it will apply to all alert groups, otherwise only to the specified alert groups
- Subject: Subject of the notification that will be sent if this rule triggers. Note that you can specify some wildcards in the subject that are expanded at runtime.
- Immediate: if set an alert is trigger per alert, if not it is cumulated with other alerts.
- Enabled: you can temporarely disable a rule by using this slider
- Comment: human readeable comment for this rule.- Priority: it specified the rule evaluation order (lower first)
- Minumum Level: the rule has no effect on alerts with level less than the specified valie
- Groups: if empty it will apply to all alert groups, otherwise only to the specified alert groups
- Subject: Subject of the notification that will be sent if this rule triggers. Note that you can specify some wildcards in the subject that are expanded at runtime.
- Immediate: if set an alert is trigger per alert, if not it is cumulated with other alerts.
- Enabled: you can temporarely disable a rule by using this slider
- Comment: human readeable comment for this rule.

Finally you can see the list of collected alerts in the main page.

![Wazuh Alerts](../img/wazuh_alerts_list.png)

Note that in the ntopng preferences page, you can set the alert retention time (by default is one year).

## Alerts Lifecycle {#alerts-lifecycle}

Every minute ntopng polls redis for new incoming alerts are processes them accordingly

- Alerts are store permanently in the database
- A notification is triggered if an alert rule matches the received alert. No alerts are generated in the ntopng alerts page, this to avoid duplicating data.

In order to deliver notifications to remote users, you need to configure a Recipient and a Notification Policy:

- Go to left menubar, Alerts -> Notifications and add a Recipient (e.g. an email address).
- Then, in the Policies tab, add a policy with "Send" set to "Wazuh Alerts" and select the Recipient (see [Notification Policies](/user_interface/shared/alerts/available_endpoints.md#notificationpolicies)).

![Wazuh Alert Recipient](../img/wazuh_recipient.png)

## Wazuh Assets Collection {#wazuh-assets-collection}

Wazuh deploys agents on monitored endpoints that continuously report status, operating system details, connectivity information, and security events to a central Wazuh Manager. By connecting ntopng to the Wazuh Manager REST API, the asset inventory can be automatically enriched with this agent-level data.

The merge process matches Wazuh agents to ntopng assets based on their IP addresses. When a match is found, the asset is updated with security metadata retrieved from Wazuh, including the agent status, operating system, registration date, and last keep-alive timestamp. Assets enriched with Wazuh data are visually distinguishable in the inventory and can be filtered separately from assets without Wazuh information.

## Prerequisites {#prerequisites}

Before enabling the integration, ensure the following requirements are met:

**ntopng Requirements:**

- ntopng with asset inventory support enabled (Enterprise M or better).
- Network connectivity from the ntopng host to the Wazuh Manager API endpoint.
- Host assets already present in the ntopng asset inventory (the integration updates existing assets only; it does not create new ones)

**Wazuh Requirements:**

- A running Wazuh Manager instance
- A Wazuh user account with read access to the `/agents` API endpoint
- The Wazuh Manager API reachable on its configured port (default: `55000`)

::: info
The integration performs a read-only query against the Wazuh API. No data is written to Wazuh.
:::

## Setup {#setup}

### Step 1: Merge Assets from Wazuh {#step-1-merge-assets-from-wazuh}

Once the credentials are saved, you can trigger the merge at any time from the asset inventory.

1. Navigate to **Network → Assets Inventory**
2. Click the **Merge Assets from Wazuh** button above the table (administrators only)
3. ntopng will authenticate against the Wazuh Manager API, retrieve the full list of registered agents, and update all matching assets

![Wazuh Merge Check](../img/wazuh_merge_check.png "Wazuh Merge Check")

The operation runs synchronously and returns a brief summary indicating how many assets were updated, how many agents had no matching ntopng asset, and whether any errors occurred.

![Wazuh Merge Completed](../img/wazuh_merge.png "Wazuh Merge Completed")

::: info
Only assets that already exist in the ntopng inventory are updated. Wazuh agents whose IP address does not match any known ntopng asset are silently skipped and counted as "not found" in the summary.
:::

In case you want to nightly automatically synchronize Wazuh with ntopng, you can avoid manual import and set this option in the wazuh preferences.

### Step 2: Review Enriched Assets {#step-2-review-enriched-assets}

After the merge completes, enriched assets can be identified and inspected in two ways.

**Visual indicator in the inventory**

Assets that have been successfully enriched with Wazuh data display a **W** badge next to their name in the asset inventory table, making them immediately recognisable at a glance.

**Filtering by Wazuh status**

The asset inventory provides a dedicated filter to narrow the view to:

- Assets **with** Wazuh information (merge was performed and data is available)
- Assets **without** Wazuh information (no merge has been performed, or no matching Wazuh agent was found)

This filter is useful to quickly identify which endpoints in your network are covered by Wazuh monitoring and which are not.

**Wazuh detail panel**

Clicking on an enriched asset opens its detail page, where a dedicated **Wazuh** section is displayed. This section contains a table with the following information retrieved from the Wazuh agent record:

| Field | Description |
|---|---|
| **Status** | Current agent status as reported by Wazuh (e.g. `active`, `disconnected`, `never_connected`) |
| **Version** | Version of the Wazuh agent installed on the endpoint |
| **Date Added (First Seen)** | Date and time the agent was first registered with the Wazuh Manager |
| **Last Keep-Alive (Last Seen)** | Date and time of the most recent heartbeat received from the agent |
| **OS** | Operating system information of the monitored endpoint |

::: info
Timestamp fields are stored and displayed in UTC, consistent with the rest of ntopng.
:::

![Wazuh Agent Information](../img/wazuh_agent.png "Wazuh Agent Information")

Above you can see an example of the information reported by Wazuh that includes (but not limited to)

- Operating System and Architecture
- Available resources (memory and CPU)
- Network Interfaces
- Open TCP/UDP server ports including process name

## Alerts {#alerts}

Every time a Wazuh merge is performed, ntopng compares the newly retrieved agent data against the previously stored state for each asset and automatically generates **informative alerts** for any change detected. These alerts are visible under the **network interface** and are labelled with the IP address of the affected host.

![Wazuh Alerts](../img/wazuh_alerts.png)

### Alert triggers {#alert-triggers}

An alert is generated for each of the following events:

| Event | Description |
|---|---|
| **New open port** | A TCP or UDP port that was not previously open is now reported as open by the Wazuh agent. |
| **Port no longer open** | A TCP or UDP port that was previously open is no longer present in the agent report. |
| **Process behind a port changed** | A port is still open, but the process (application) listening on it has changed since the last merge. |
| **Network interface added** | A new network interface has appeared on the endpoint. Virtual interfaces whose name starts with `veth` are excluded from this check as they are not considered meaningful (e.g. container-generated interfaces). |
| **Network interface removed** | A previously known network interface is no longer reported by the agent. As above, `veth`-prefixed interfaces are ignored. |

### New assets {#new-assets}

When a Wazuh agent is matched to an ntopng asset **for the first time** (i.e. the asset has no prior Wazuh data), ntopng treats the entire set of data received as new and generates a single alert that summarises all ports, processes, and network interfaces discovered on that endpoint. This provides an immediate baseline notification whenever a previously unknown host is enrolled.

### Alert format {#alert-format}

All Wazuh-generated alerts share the following properties:

- **Severity**: Informative
- **Interface**: The network interface where ntopng observes the host
- **Label**: IP address of the affected host

This makes it straightforward to correlate alerts with specific hosts directly from the ntopng alert view, and to filter or aggregate them by IP address across the fleet.

### Keeping Data Up to Date {#keeping-data-up-to-date}

The Wazuh integration does not poll the Wazuh API continuously. The merge must be triggered manually from the asset inventory, or scheduled nightly via the automatic synchronization option in the Wazuh preferences.

### Troubleshooting {#troubleshooting}

**The "Merge Assets from Wazuh" button returns an error**

- Verify that the Wazuh URL, username, and password saved are correct
- Confirm that the Wazuh Manager API is reachable from the ntopng host on the configured port
- Check that the Wazuh user account has permission to call the `/agents` endpoint
- Inspect the ntopng log for additional error details

**Agents are retrieved but no assets are updated**

- The merge matches agents to assets exclusively by IP address. Ensure that the IP addresses reported by Wazuh agents correspond to IPs already present in the ntopng asset inventory
- Assets that have never been seen by ntopng cannot be created by the merge; traffic must be observed first for an asset to exist in the inventory

**The "W" badge does not appear after the merge**

- Reload the asset inventory page; the badge is rendered client-side and may require a page refresh
- Confirm the merge summary reported at least one updated asset

**No alerts are generated after the merge**

- Alerts are only generated when a change is detected relative to the previous merge. If this is the first merge ever performed, a baseline alert is created for each newly matched asset. If no changes occurred since the last merge, no alerts are produced.
- Confirm that the alerts view is filtered to show the correct network interface, as Wazuh alerts are associated with the interface on which the host is observed by ntopng.
