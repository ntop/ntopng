.. _AlertsExplorer:

Alerts Explorer
===============

ntopng alerts are:

- Evaluated with Behavioural Checks for pools of hosts, interfaces, SNMP devices, and other network elements
- Delivered to recipients using type- or severity-based criteria

Contrary to tools based on signatures, ntopng is a behavioural-based tool. Below you can read more about available behavioural checks and how alerts are delivered to recipients.


Alerts triggered by ntopng are stored in a databased (SQLite or ClickHouse) and can be visualized 
and managed using the built-in Alerts Explorer, in addition to delivering them to external endpoints
by using :ref:`DeliveringAlertsToRecipients`.

Alerts are organized in the Alerts Explorer according to the entity (subject for which the alert has 
been generated), whose list includes Host, Interface, Network, Flow, etc. as described in :ref:`BasicConceptAlerts`.

Alerts can be just triggered as one-shot, or can have a duration, that is, they are active for a 
certain period of time (in the *engaged* state). This period of time starts when a condition is verified 
(e.g. a threshold is met) and stops when the condition is no longer verified (and alerts are moved in the
*past* state). For this reason, such alerts are said to be *engaged* or *past*, depending on whether the 
triggering threshold is still met or not. Alerts on flows are always one-shot.


.. toctree::
    :maxdepth: 2

    others/alerts_graph
    alerts_type/engaged_alerts
    alerts_type/past_alerts
    alerts_type/flow_alerts
    others/alerts_filters
    others/custom_queries
    others/mitre_classification
    others/risk_and_check_exclusion
    remediations/index

