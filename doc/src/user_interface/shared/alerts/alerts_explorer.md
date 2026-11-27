---
title: "Alerts Explorer"
description: "ntopng alerts are: Contrary to tools based on signatures, ntopng is a behavioural-based tool. Below you can read more about available behavioural checks..."
outline: [2, 3]
lastUpdated: 2026-11-24T15:23:43+01:00
---

<a id="alertsexplorer"></a>

# Alerts Explorer {#alerts-explorer}

ntopng alerts are:

- Evaluated with Behavioural Checks for pools of hosts, interfaces, SNMP devices, and other network elements
- Delivered to recipients by notification policies (severity, category, pool and tags criteria)

Contrary to tools based on signatures, ntopng is a behavioural-based tool. Below you can read more about available behavioural checks and how alerts are delivered to recipients.

Alerts triggered by ntopng are stored in a databased (SQLite or ClickHouse) and can be visualized
and managed using the built-in Alerts Explorer, in addition to delivering them to external endpoints.

Alerts are organized in the Alerts Explorer according to the entity (subject for which the alert has
been generated), whose list includes Host, Interface, Network, Flow, etc. as described in [Alerts](/basic_concepts/alerts.md#basicconceptalerts).

Alerts can be just triggered as one-shot, or can have a duration, that is, they are active for a
certain period of time (in the *engaged* state). This period of time starts when a condition is verified
(e.g. a threshold is met) and stops when the condition is no longer verified (and alerts are moved in the
*past* state). For this reason, such alerts are said to be *engaged* or *past*, depending on whether the
triggering threshold is still met or not. Alerts on flows are always one-shot.

The Alerts Explorer shows the *Engaged* alerts and *All* the alerts. In ntopng Enterprise XXL and
above, alerts are also grouped into [Issues](/user_interface/shared/alerts/issues.md#issues), which track each problem with a status.

- [Issues](/user_interface/shared/alerts/issues.md)
  - [How Alerts Are Grouped](/user_interface/shared/alerts/issues.md#how-alerts-are-grouped)
  - [How Issues Are Resolved](/user_interface/shared/alerts/issues.md#how-issues-are-resolved)
  - [Issues Page](/user_interface/shared/alerts/issues.md#issues-page)
  - [Issue Details](/user_interface/shared/alerts/issues.md#issue-details)
  - [Actions](/user_interface/shared/alerts/issues.md#actions)
- [Alerts Graph](/user_interface/shared/alerts/others/alerts_graph.md)
  - [Graph Structure](/user_interface/shared/alerts/others/alerts_graph.md#graph-structure)
  - [Color Insights](/user_interface/shared/alerts/others/alerts_graph.md#color-insights)
  - [How To Use The Alerts Graph](/user_interface/shared/alerts/others/alerts_graph.md#how-to-use-the-alerts-graph)
  - [License Pre Requisites](/user_interface/shared/alerts/others/alerts_graph.md#license-pre-requisites)
- [Engaged Alerts](/user_interface/shared/alerts/alerts_type/engaged_alerts.md)
- [Past Alerts](/user_interface/shared/alerts/alerts_type/past_alerts.md)
- [Flow Alerts](/user_interface/shared/alerts/alerts_type/flow_alerts.md)
  - [Alert Details](/user_interface/shared/alerts/alerts_type/flow_alerts.md#alert-details)
  - [Alerts Map](/user_interface/shared/alerts/alerts_type/flow_alerts.md#alerts-map)
- [Alerts Filters](/user_interface/shared/alerts/others/alerts_filters.md)
- [Custom Queries](/user_interface/shared/alerts/others/custom_queries.md)
- [Mitre Classification](/user_interface/shared/alerts/others/mitre_classification.md)
  - [Mitre ATT&CK Framework Integration](/user_interface/shared/alerts/others/mitre_classification.md#mitre-att-ck-framework-integration)
  - [Security Report](/user_interface/shared/alerts/others/mitre_classification.md#security-report)
  - [Alerts Explorer](/user_interface/shared/alerts/others/mitre_classification.md#alerts-explorer)
  - [Alert Details](/user_interface/shared/alerts/others/mitre_classification.md#alert-details)
- [Remediations](/user_interface/shared/alerts/remediations/index.md)
  - [Remediations for nDPI Risks](/user_interface/shared/alerts/remediations/ndpi_flow_risks.md)
  - [Remediations for ntopng Flow Risks](/user_interface/shared/alerts/remediations/ntopng_flow_risks.md)
  - [Remediations for Host Risks](/user_interface/shared/alerts/remediations/host_risks.md)

