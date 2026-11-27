---
title: "RESTful API v2 Specification"
description: "The HTTP/HTTPS authentication should be used, for example with curl it is possible to specify username and password with"
outline: [2, 3]
lastUpdated: 2023-01-26T17:04:41+01:00
---

<a id="restapidocv2-target"></a>

# RESTful API v2 Specification {#restful-api-v2-specification}

## Authentication {#authentication}

The HTTP/HTTPS authentication should be used, for example with `curl`
it is possible to specify username and password with
`-u <user>:<password>`

Using HTTPS is recommended for security. See [this post](https://www.ntop.org/ntopng/best-practices-to-secure-ntopng/) to enable HTTPS.

## Request Format {#request-format}

Parameters can be provided both using GET with a query string or
POST using JSON (in this case please make sure the correct
Content Type is provided). For example, to download data for a host you can
use the below `curl` command line using GET:

```bash
curl -s -u admin:admin "http://192.168.1.1:3000/lua/rest/v2/get/host/data.lua?ifid=1&host=192.168.1.2"
```

or the below `curl` command line using POST:

```bash
curl -s -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.2"}' "http://192.168.1.1:3000/lua/rest/v2/get/host/data.lua"
```

Please check the *Examples* section for more examples.

## Response Format {#response-format}

An API response is usually represented by a JSON message matching a standard structure.
This JSON message consists of an envelope containing:

- a return code *rc*
- a human-readable string *rc_str* describing the return code
- the actual response in *rsp*

Example:

```text
{
 "rc": 0
 "rc_str": "OK",
 "rsp": {
    ...
 }
}
```

## API {#api}

<a id="nEdge"></a>

<a id="Interfaces"></a>

## Interfaces

### POST /lua/pro/rest/v2/add/interface/db_flows.lua

**Analyse historical flows as live flows**

**Description:** Loads the historical flows matching the time range and the flow filters (the same parameters of the Historical Flows page) into a runtime interface named Database, limited by the flow cache size. Answers { new_ifid, max_num_flows }. Administrators only, ClickHouse.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE or NOT_ENABLED (no ClickHouse); `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR (the interface could not be created)

### GET /lua/pro/rest/v2/get/lightview/aggregate.lua

**Aggregate a REST endpoint across all interfaces (Overview)**

**Description:** Used by the Overview (lightview) mode: forwards the request to the specified REST endpoint once per local interface (setting ifid accordingly) and merges the results according to the dashboard component type. All the other query parameters are forwarded to the endpoint, except ifid. Enterprise only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `endpoint` | query | Path of the REST endpoint to query on each interface (e.g. /lua/rest/v2/get/interface/l7/stats.lua) | string |
| `component` | query | How to merge the per-interface results: pie, badge, table, sankey or timeseries. When omitted, the result of the endpoint is returned as is (the last interface queried). | string |
| `max_values` | query | Maximum number of slices for the pie component (default 10) | integer |

**Responses**

`0` OK. Merged data, in the same format as the forwarded endpoint (empty if endpoint is not set)

### POST /lua/pro/rest/v2/get/lightview/aggregate.lua

**Aggregate a REST endpoint across all interfaces (Overview), with a request body**

**Description:** Same as GET, for endpoints that take a JSON body. With endpoint=/lua/rest/v2/get/timeseries/batch.lua, each query in the body is run on every interface (the ifid in ts_query is replaced) and the series are summed into one serie per query; queries with "split": true also return one serie per interface (split_series).

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `endpoint` | query | Path of the REST endpoint to query on each interface | string |
| `component` | query | How to merge the per-interface results (see GET) | string |
| `payload` | body | JSON body forwarded to the endpoint (e.g. the queries of timeseries/batch.lua) | object |

**Responses**

`0` OK. Merged data, in the same format as the forwarded endpoint

### GET /lua/pro/rest/v2/get/traffic_report/data.lua

**Get the traffic report of an interface, network or host**

**Description:** Traffic of each hour (report=daily) or day (weekly, monthly) of the period containing epoch_begin, next to the same bucket of the previous period: rows [{ tstamp, bytes, activity (active seconds), prev_bytes, prev_activity }], with epoch_begin/epoch_end of the period and the start of the previous/next period. Reads the RRD timeseries: Enterprise M, RRD timeseries driver, not on pcap files.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host (IP, with @vlan for the VLAN hosts); default the interface | string |
| `network` | query | Local network identifier; default the interface | integer |
| `report` | query | Period | string |
| `epoch_begin` | query | An epoch inside the period (default now) | integer |

**Responses**

`0` OK; `-1` NOT_FOUND (no traffic timeseries for the entity); `-2` INVALID_INTERFACE (missing ifid, or an interface the user cannot see) or NOT_ENABLED (no RRD driver, or pcap file); `-3` NOT_GRANTED (license, or a host/network outside the allowed networks of the user); `-5` INVALID_ARGUMENTS (unknown report or network)

### GET /lua/rest/v2/get/asn/get_as_data.lua

**Get the autonomous systems of an interface with their traffic**

**Description:** Live: the active ASes of the interface (since startup). Historical (is_live=false, needs ClickHouse): the ASes of the flows in [epoch_begin, epoch_end]. rsp is an array of records: asn, asname (none for ASN 0, the private hosts), num_hosts, avg_host_score, score, alerted_flows, seen_since (epoch), bytes_sent, bytes_rcvd, traffic, throughput (bytes/s, the GUI shows it in bps; historical: average from the first to the last flow of the AS in the time range), breakdown {bytes_sent, bytes_rcvd}, breakdown_role {bytes_other, bytes_transit, bytes_peering, bytes_ix}, is_customer_asn / is_sub_customer_asn / is_remote_asn (ASN configuration), is_in_memory (historical only: the AS has active hosts now).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `is_live` | query | true (default) live data, false historical data (ClickHouse) | boolean |
| `epoch_begin` | query | Historical only: start of the time range (epoch) | integer |
| `epoch_end` | query | Historical only: end of the time range (epoch) | integer |
| `show_as` | query | all (default), my_as, my_customer_as, remote_as or other_as (ASN configuration) | string |
| `interface_role` | query | Enterprise M: all (default), ix, peering or transit (SNMP interface role) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-61` CLICKHOUSE_MISSING (historical data without ClickHouse)

### GET /lua/rest/v2/get/asn/get_top_asn.lua

**Get the top autonomous systems of an interface**

**Description:** The top ASes by traffic, live or in [epoch_begin, epoch_end] (is_live=false, needs ClickHouse): used for the top ASN chart. rsp is an array of AS records (asn, asname, traffic and the per-role bytes).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `is_live` | query | true (default) live data, false historical data (ClickHouse) | boolean |
| `epoch_begin` | query | Historical only: start of the time range (epoch) | integer |
| `epoch_end` | query | Historical only: end of the time range (epoch) | integer |
| `show_as` | query | all (default), my_as, my_customer_as, remote_as or other_as | string |
| `interface_role` | query | Enterprise M: all (default), ix, peering or transit | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-61` CLICKHOUSE_MISSING

### GET /lua/rest/v2/get/interface/address.lua

**Get interface IP addresses**

**Description:** List of interface IP addresses is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/interface/bcast_domains.lua

**Get interface broadcast domains**

**Description:** Interface broadcast domains as detected from ARP traffic and broadcast traffic are returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/interface/lightview/data.lua

**Get interface data aggregated from all interfaces (Overview)**

**Description:** Interface data aggregated (summed) across all the interfaces, as shown by the Overview (lightview) mode in the Interface Details page. The response is a subset of /lua/rest/v2/get/interface/data.lua, plus the list of aggregated interfaces. Export stats (db, es, kafka, syslog) are reported only when the corresponding export is enabled, alert counters only when the user has the alerts capability, ZMQ counters only when at least one interface is a collector.

**Produces:** `application/json`

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/interface/config.lua

**Get the settings of an interface**

**Description:** Administrators only. The settings that apply to the interface and their values: custom_name, speed (Mbit/s), scaling_factor, lbd_by_mac (hosts of the local broadcast domain identified by MAC; lbd_locked when forced to IP), top_talkers, flow_dump, automatic_reports, mirrored and gw_macs, network_discovery, companion and companions, recording_provider and recording_providers, disaggregation and disaggregation_modes, show_dyn_traffic, push_host_filters. A setting missing from the answer does not apply to the interface. Not for pcap files.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE (missing, not allowed or a pcap file); `-3` NOT_GRANTED (administrators only)

### GET /lua/rest/v2/get/interface/data.lua

**Get interface data**

**Description:** Interface data is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/interface/dscp/stats.lua

**Get IP DSCP statistics for an interface**

**Description:** DSCP statistics

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/interface/l7/stats.lua

**Get L7 statistics for an interface**

**Description:** nDPI statistics

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `ndpistats_mode` | query | Stats mode: 'sinceStartup' or 'count' | string |
| `breed` | query | Show breed | boolean |
| `ndpi_category` | query | Show nDPI category | boolean |
| `all_values` | query | Return all the values available | boolean |
| `max_values` | query | Get at most max_values, by default 5 | int16 |
| `collapse_stats` | query | Collapse the returned stats into 'Other' stats if bytes/flows are too low (&lt; 3%) | boolean |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/interface/overview.lua

**Get the interface overview**

**Description:** Identity and configuration of an interface, as shown by its Overview page: name, type, MTU and speed, paused state, connected nProbe instances, flow export backends. Administrators also get the traffic recording windows, the disk usage and the ZMQ encryption public key. The live counters are returned by get/interface/data.lua. With view=lightview (all the interfaces together) only is_light_view, can_reset, show_alerts, timeseries_enabled, exports, export_enabled, dedup_enabled and nprobe_page are returned (the aggregated counters are in get/interface/lightview/data.lua).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the interface of the session) | integer |
| `view` | query | lightview: all the interfaces together | string |

**Responses**

`0` OK: { ifid, name, label, description, mac, type, inline, has_traffic_directions, mtu, speed_mbps, is_view, is_sub_interface, is_packet_interface, is_pcap_dump, is_syslog, is_netfilter, is_paused, can_pause, can_reset, can_live_capture, num_probes, nprobe_page, show_alerts, timeseries_enabled, has_role_traffic, has_flow_collection, db_stats, dedup_enabled, exports: [{ id, label }], export_enabled, export_direct, zmq_encryption_key, recording, storage, external_stats, maps_available, is_asn_mode }; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/interface/icmp_stats.lua

**Get the ICMP messages of an interface**

**Description:** ICMP messages seen on the interface (or by a host): type, code and packets.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the interface of the session) | integer |
| `version` | query | 4 (default) or 6 | string |
| `host` | query | Host IP (optional): the counters of this host instead of the interface | string |
| `vlan` | query | VLAN of the host | integer |

**Responses**

`0` OK: [{ icmp_type, icmp_code, packets, icmp_message: { label, url } }]; `-2` INVALID_INTERFACE (missing ifid or interface not allowed)

### GET /lua/rest/v2/get/interface/pkt_distribution.lua

**Get the packet size or IP version distribution**

**Description:** Packets of the interface by size (sizes below 5% grouped as Other) or by IP version.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `distr` | query | size (default) or ipver | string |

**Responses**

`0` OK: [{ label, value }] (value: packets); `-2` INVALID_INTERFACE (missing ifid or interface not allowed)

### GET /lua/rest/v2/get/interface/tcp_flags_distribution.lua

**Get the TCP flags distribution**

**Description:** TCP packets of the interface (or of a host) by flags: SYN, SYN/ACK, FIN/ACK, RST. Without TCP packets: [{ label: Other, value: 100 }].

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the interface of the session) | integer |
| `host` | query | Host IP (optional): the counters of this host instead of the interface | string |
| `vlan` | query | VLAN of the host | integer |

**Responses**

`0` OK: [{ label, value }] (value: packets); `-2` INVALID_INTERFACE (missing ifid or interface not allowed)

### GET /lua/rest/v2/get/internals/periodic_activities.lua

**Get the periodic activities**

**Description:** State and timings of the periodic activities (the Lua scripts run every second, minute, 5 minutes...) of an interface. Without ifid: the ones of the system interface and of every allowed interface, each row with iface_id and iface_name.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (-1: the system one; none: all) | integer |
| `periodic_script` | query | Only this activity (e.g. minute) | string |
| `periodic_script_issue` | query | Only the activities with this issue (any_issue: any) | string |

**Responses**

`0` OK: [{ iface_id, iface_name, script, state, periodicity, max_duration_secs, last_start_time, last_duration_ms, busy_pct, tot_not_executed, tot_running_slow, issues, ... }]; `-2` INVALID_INTERFACE (ifid not allowed)

### GET /lua/rest/v2/get/syslog/producer/list.lua

**Get the syslog producers**

**Description:** Administrators only. The hosts that send their logs to a syslog interface and the type of their logs.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK: [{ host, producer, producer_title }]; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only)

### POST /lua/rest/v2/add/syslog/producer.lua

**Add or change a syslog producer**

**Description:** Administrators only, syslog interfaces. Adds a producer, or changes the one of old_syslog_producer_host.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS: rsp = { field } the refused one (exists: true when the name/host is already used)

### POST /lua/rest/v2/delete/syslog/producer.lua

**Delete a syslog producer**

**Description:** Administrators only, syslog interfaces.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS: rsp = { field } the refused one (exists: true when the name/host is already used)

### GET /lua/pro/rest/v2/get/interface/sub_interfaces.lua

**Get the sub-interfaces of an interface**

**Description:** Administrators only, Enterprise M. The custom disaggregation: the sub-interfaces receiving the traffic matching a filter.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK: [{ name, filter }]; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only)

### POST /lua/pro/rest/v2/add/interface/sub_interface.lua

**Add or change a sub-interface**

**Description:** Administrators only, Enterprise M. Adds a sub-interface, or changes the one of old_name. The filter is nBPF (packet interfaces) or xnBPF (flow interfaces).

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS: rsp = { field } the refused one (exists: true when the name/host is already used)

### POST /lua/pro/rest/v2/delete/interface/sub_interface.lua

**Delete a sub-interface**

**Description:** Administrators only, Enterprise M.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS: rsp = { field } the refused one (exists: true when the name/host is already used)

### GET /lua/rest/v2/get/ntopng/interfaces.lua

**Get ntopng actively monitored interfaces names and ids**

**Description:** Interface name and integer interface id for each actively monitored ntopng interface

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v2/get/interface/recording/config.lua

**Read the traffic recording (n2disk) settings of an interface**

**Description:** Administrators only, with n2disk installed. managed: ntopng runs n2disk (else provider names the external one and there are no settings). enabled, jobs_available (Enterprise M), smart_available (Enterprise XL), reminder (external n2disk instances detected), max_pcap_mb (size extracted PCAPs are split at). settings: disk_space / smart_disk_space / max_space (GB), bpf_filter, snaplen (bytes), max_file_size (MB, null: auto) and max_file_size_auto, pcap_path, smart_pcap_path, smart_enabled; ZMQ collectors also ext_interfaces [{name, label}], ext_ifname, flow_export. storage (bytes): total, avail, system_used, if_used, extraction_used. A view returns viewed_interfaces [{ifid, name}] (the ones with recording) instead.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### POST /lua/rest/v2/set/interface/recording/config.lua

**Save the traffic recording (n2disk) settings of an interface and start or stop n2disk**

**Description:** Administrators only, with n2disk installed and managed by ntopng (not on views). All the fields are applied: a missing toggle is off, a missing number takes its default. An invalid value answers INVALID_ARGUMENTS with rsp.field. Answers enabled and started (n2disk configured and restarted).

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/interface/recording/status.lua

**Read the traffic recording (n2disk) status of an interface**

**Description:** Administrators only, with n2disk installed (not on views). enabled, running, external (n2disk run by another provider). When enabled: first_epoch / last_epoch (dump window), start_epoch, bytes, packets, dropped, smart {first_epoch, last_epoch}, log (last 32 lines of the n2disk log, most recent first); external and running: extraction {ok, status: OK | ERR_MISSING_TIMELINE | ERR_TIMELINE_PATH_NOT_EXISTING | ERR_UNABLE_TO_ACCESS_TIMELINE}.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### POST /lua/rest/v2/set/interface/recording/restart.lua

**Restart the traffic recording (n2disk) of an interface**

**Description:** Administrators only, with n2disk installed, the recording enabled and managed by ntopng (else INVALID_ARGUMENTS). Nothing is done when n2disk is already running.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/pod/list.lua

**Get the Kubernetes pods**

**Description:** Kubernetes pods seen in the flows of the interface: pod, num_containers, flows_as_client, flows_as_server, rtt_as_client, rtt_as_server, rtt_variance_as_client, rtt_variance_as_server (RTT in ms)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE: the user cannot access the interface

### GET /lua/rest/v2/get/container/list.lua

**Get the containers**

**Description:** Containers (Docker or Kubernetes) seen in the flows of the interface: id, name, pod, flows_as_client, flows_as_server, rtt_as_client, rtt_as_server, rtt_variance_as_client, rtt_variance_as_server (RTT in ms)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `pod` | query | Only the containers of this Kubernetes pod | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE: the user cannot access the interface

### POST /lua/rest/v2/set/interface/alias.lua

**Set interface alias**

**Description:** Set interface custom name

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface ID | string |
| `custom_name` | formData | Custom name | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/set/interface/config.lua

**Save settings of an interface**

**Description:** Administrators only. Only the fields in the body are changed (the others are kept), and only the ones that apply to the interface. Nothing is saved when a value is refused.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK: { restart_required }; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS: rsp = { field } the refused one

### POST /lua/rest/v2/set/interface/idle_state.lua

**Pause or resume an interface**

**Description:** Administrators only. Pauses (active=false) or resumes (active=true) the monitoring of an interface: while paused its traffic is not processed. Not available for pcap files and nEdge netfilter queues.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK: { is_paused }; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS

<a id="Hosts"></a>

## Hosts

### GET /lua/pro/rest/v2/charts/host/map.lua

**Get the hosts map data of an interface**

**Description:** Enterprise only. Up to 64 local and 64 remote active hosts placed by the chosen criteria. rsp.series: [{name: local|remote, base_url (host details page), data: [{x, y, z (bubble radius in px, 3-33, from the host traffic), meta: {label (host name or IP), url_query (host=&lt;ip>@&lt;vlan>)&#125;&#125;]}]. x/y per bubble_mode: 0 flows as server/client, 1 unreachable flows as server/client, 2 alerted flows as server/client, 3 DNS positive replies/sent queries, 4 SYN sent/received, 5 SYN sent/RST received, 6 SYN sent/SYN-ACK received, 7 TCP packets sent/received, 8 TCP bytes sent/received, 9 active alerted flows as server/client, 10 bytes/packets ratio, 11 client/server score, 12 blacklisted flows as client/server, 13 unidirectional TCP flows as client/server. Modes 4-6 need a packet interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `bubble_mode` | query | Criteria, 0-13 (default 0) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/interface/local_hosts_report.lua

**Get the local hosts activity report**

**Description:** Traffic of the local hosts (assets) in a time range, from the host timeseries (live data when epoch_begin = epoch_end): one row per asset, with the traffic of its host on the VLAN seen last (the VLAN is not part of the identity of an asset). Each row: ip, vlan (the VLAN seen last), host (ip@vlan, the host whose traffic is reported), host_key, name, online, bytes_sent, bytes_rcvd, local_traffic, remote_traffic, total_traffic, availability (traffic per time slot) and max_value_per_point (max of each slot over the page). Enterprise M only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start of the time range (epoch seconds). Equal to epoch_end = live data | integer |
| `epoch_end` | query | End of the time range (epoch seconds) | integer |
| `preset` | query | Time range preset, sets the number of availability points: hour (12), day (24), week (7), month (30), year (12) (optional) | string |
| `host_visibility` | query | Hosts listed: only_traffic (default), no_traffic, visible, hidden (optional) | string |
| `start` | query | Pagination: index of the first host | integer |
| `length` | query | Pagination: number of hosts | integer |
| `sort` | query | Sort column: ip, name, bytes_sent, bytes_rcvd, local_traffic, remote_traffic, total_traffic (optional) | string |
| `order` | query | Sort order: asc or desc (optional) | string |

**Responses**

`0` OK; `-1` NOT_FOUND (not Enterprise M); `-2` INVALID_INTERFACE (missing time range, or an interface the user cannot access)

### POST /lua/pro/rest/v2/edit/host/visibility.lua

**Hide or show a host in the local hosts activity report**

**Description:** Hides a host from the local hosts activity report (listed again with host_visibility=hidden) or shows it again. Enterprise M and administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-3` NOT_GRANTED (Enterprise M and administrators only); `-4` INVALID_HOST

### GET /lua/pro/rest/v2/get/host/asset_details.lua

**Get the details of an asset**

**Description:** Details of an asset of the inventory as raw values: ifid, key, ip, vlan (the VLAN seen last), vlans [{ id, name, online }] (the VLANs where the IP of a host asset has been seen: the VLAN is not part of its identity), mac, name, title, device_type (id), manufacturer, model, os_id/os_name, first_seen/last_seen (epochs), online (the host of any of its VLANs is), dhcp, snmp_name, network { id, name }, tags [{ id, name, color, description, reserved, protocols, risks, ttl }] (the definition of the tags, see rest/v2/get/tag/tags_list.lua), names [{ source, name }], usernames [{ name, protocol }], tcp_fingerprints [&lt;TCP fingerprint>] (the ones of all its hosts), switch { ip, name, port, port_name, trunk, num_ports }, server_ports { tcp, udp: [{ port, name }] }, wazuh (agent: status, version, os, cpu, ram, open_ports, ifaces). Enterprise M; assets of hosts outside the allowed networks are not shown. Needs the historical flows capability (non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `serial_key` | query | Asset key (key field of rest/v2/get/host/assets.lua) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (no serial_key)

### GET /lua/pro/rest/v2/get/interface/top/local/talkers.lua

**Get Top local talkers**

**Description:** Get the Top 10 local talkers

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | number |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/interface/top/remote/talkers.lua

**Get Top remote talkers**

**Description:** Get the Top 10 remote talkers

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | number |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/interface/top/ts_stats.lua

**Get Top Timeseries stats**

**Description:** Get the Top timeseries stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | Start time (epoch) | integer |
| `ts_query` | query | data used to get the timeseries; e.g. format: 'ifid:1,protocol:DNS' , where 'ifid:1' stands for interface ID 1 and 'protocol:DNS' stands for DNS protocol information | string |
| `detail_view` | query | Top information requested, currently available: top_protocols -> Top Application data, top_categories -> Top Categories data, top_senders -> Top Local Senders data, top_receivers -> Top Local Receivers data | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/country/list.lua

**Get the countries of the active hosts**

**Description:** The countries (from the geolocation database) of the hosts active on the interface. rsp is an array of records: name (ISO 3166 country code), hosts (active hosts), seen_since (epoch of the first packet), score, bytes_sent, bytes_rcvd, traffic (bytes), throughput (bps). recordsTotal/recordsFiltered: number of countries. Any user can call it (interface restrictions apply).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/geo_map/hosts.lua

**Get the geolocated hosts of an interface**

**Description:** The active hosts with a known location (latitude/longitude from the geolocation database), at most 512. rsp is an array of records: ip, name, vlan {id, name}, lat, lng, country (ISO 3166 alpha-3), country_code (alpha-2), country_id, city (when known), scoreClient, scoreServer, numAlerts (alerted active flows), isAlert (score > 0), isRoot. Any user can call it (interface and network restrictions apply).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `hosts_category` | query | 0 active hosts by traffic (default), 1 alerted hosts by score, 2 local hosts, 3 remote hosts | integer |
| `host` | query | When set, the hosts the given host is talking with (active flows) instead of the category | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/active.lua

**Get active hosts**

**Description:** List of active hosts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `currentPage` | query | Pagination: page (optional) | integer |
| `perPage` | query | Pagination: items per page (optional) | integer |
| `sortColumn` | query | Pagination: column for sorting (e.g. ip, name, since, last, alerts, country, vlan, num_flows, traffic, thpt) (optional) | string |
| `sortOrder` | query | Pagination: sorting order: 'asc' or 'desc' (optional) | string |
| `all` | query | Get all hosts (optional) | boolean |
| `mode` | query | Mode filter: all, local, remote, broadcast_domain, filtered, blacklisted, dhcp (optional) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/host/active_list.lua

**Get the active hosts list**

**Description:** Active hosts of the interface, one page at a time, with the filters of the Hosts page. Each row: host (ip, vlan, mac address, os, country and flags), hostname, first_seen, last_seen, throughput, bytes, alerts, num_flows, score, isBlocked (nEdge), location (nEdge). recordsTotal is the number of hosts matching the filters. Only the hosts of the networks the user is allowed to see are listed.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (optional, default: the selected one). An interface the user cannot access answers INVALID_INTERFACE | integer |
| `start` | query | Pagination: index of the first host (optional) | integer |
| `length` | query | Pagination: number of hosts (optional) | integer |
| `sort` | query | Sort column: ip_address, hostname, vlan, num_flows, alerts, score, first_seen, throughput, bytes, location (nEdge only). Any other value sorts by ip_address (optional) | string |
| `order` | query | Sort order: asc or desc (optional) | string |
| `map_search` | query | Text search on the hosts (optional) | string |
| `mode` | query | Hosts filter: local, local_no_tx, local_no_tcp_tx, remote, remote_no_tx, remote_no_tcp_tx, broadcast_domain, broadcast_multicast, filtered, blacklisted, dhcp (optional) | string |
| `version` | query | IP version: 4 or 6 (optional) | integer |
| `traffic_type` | query | Direction: one_way or bidirectional (optional) | string |
| `vlan` | query | VLAN id (optional) | integer |
| `network` | query | Local network id (optional) | integer |
| `network_cidr` | query | Network in CIDR format (optional) | string |
| `pool` | query | Host pool id (optional) | integer |
| `asn` | query | Autonomous System number (optional) | integer |
| `country` | query | Country code, e.g. IT (optional) | string |
| `os` | query | Operating system id (optional) | integer |
| `mac` | query | MAC address (optional) | string |
| `protocol` | query | nDPI application protocol id (optional) | integer |
| `deviceIP` | query | Flow exporter IP (optional) | string |
| `location` | query | nEdge only: lan, wan or unknown (optional) | string |
| `label` | query | Host tag id (optional) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/host/custom_data.lua

**Get host custom data**

**Description:** Custom data is returned for one or all hosts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `field_alias` | query | Field alias | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT; `-8` BAD_CONTENT

### GET /lua/rest/v2/get/host/data.lua

**Get host data**

**Description:** Host data is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address (IP or IP@VLAN if traffic is tagged) | string |
| `host_stats` | query | false: without the host statistics (default: included) | boolean |
| `host_stats_flows` | query | true: also the active flows of the host (default: not included) | boolean |
| `limit` | query | Maximum number of flows returned with host_stats_flows=true | integer |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT; `-8` BAD_CONTENT

### GET /lua/rest/v2/get/host/used_ports.lua

**Get the ports of a host**

**Description:** The server ports an active host answered on (local_server_ports) and the server ports it contacted (remote_contacted_ports), each as "&lt;l4 proto>:&lt;port>" -> application.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address (IP or IP@VLAN if traffic is tagged) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/icmp.lua

**Get the ICMP messages of a host**

**Description:** The ICMP messages of an active host per version (ICMPv4, ICMPv6): "&lt;type>,&lt;code>" -> packets sent and rcvd, last_host_sent_peer and last_host_rcvd_peer.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address (IP or IP@VLAN if traffic is tagged) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/dns.lua

**Get the DNS counters of a host**

**Description:** The DNS counters of an active host (dns.sent / dns.rcvd: num_queries, num_replies_ok, num_replies_error and the queries per type) and the DoH/DoT servers it used (doh_dot: ip, vlan_id, num_uses).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address (IP or IP@VLAN if traffic is tagged) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/http.lua

**Get the HTTP counters of a host**

**Description:** The HTTP counters of an active host: requests sent per method (http.sender.query), responses received per code (http.receiver.response) and the virtual hosts it served (http.virtual_hosts: bytes sent/rcvd, requests).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address (IP or IP@VLAN if traffic is tagged) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/overview.lua

**Get the overview of a host**

**Description:** An active host as raw values (host): identity and flags (MAC, router, VLAN, OS, ASN, network, country, local/private/multicast/broadcast/blacklisted...), first/last seen, bytes and packets sent/rcvd, local/non-local bytes, score as client/server with its network/security breakdown, active/total/alerted/unreachable flows, blacklisted and unidirectional TCP flows, peers, unresponsive peers, contacted servers, TCP retransmissions/out of order/lost/keep-alive, alerts, names, OS learning, flow exporter. ext: pool, symbolic MAC and device type, local network alias and site, host tags (name, or name_i18n for the built-in ones), asset key, ICMP active monitoring state, notes, page flags. counters=true: only host.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address (IP or IP@VLAN if traffic is tagged) | string |
| `counters` | query | true: only the host values (no ext), for the live updates | boolean |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/dscp/stats.lua

**Get IP DSCP statistics for a host**

**Description:** DSCP statistics

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `vlan` | query | VLAN ID | integer |
| `direction` | query | Select direction: 'sent' or 'recvd' (default) | boolean |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/host/interfaces.lua

**Get host interfaces**

**Description:** All interface ids of a given host are returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface identifier | integer |
| `host` | formData | Host address | string |
| `vlan` | formData | VLAN ID | integer |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/l7/stats.lua

**Get L7 statistics for a host**

**Description:** nDPI statistics

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `vlan` | query | VLAN ID | integer |
| `breed` | query | Show breed | boolean |
| `ndpi_category` | query | Show nDPI category | boolean |
| `collapse_stats` | query | Collapse the returned stats into 'Other' stats if bytes/flows are too low (&lt; 3%) | boolean |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/set/host/alias.lua

**Set host alias**

**Description:** Set host custom name

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | Host address | string |
| `custom_name` | formData | Custom name | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/set/host/reset_stats.lua

**Reset the counters of a host**

**Description:** Resets the counters of an active host: all of them (reset_all) or only the blacklisted flows/contacts counters (reset_blacklisted). Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/set/host/traffic_policy.lua

**Drop or allow the traffic of a host**

**Description:** Traffic policy of a local host on an inline interface: block (drop all its traffic), allow (stop dropping it), drop_flows (drop its active flows once). Answers the current state (blocked). Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-1` NOT_FOUND (not an active local unicast host); `-2` INVALID_INTERFACE, or NOT_ENABLED (not an inline interface); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/trigger/host/alert.lua

**Trigger an external alert on a host**

**Description:** Trigger alert

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface identifier | integer |
| `host` | formData | Host address | string |
| `vlan` | formData | VLAN ID | integer |
| `score` | formData | Set the alert score | boolean |
| `info` | formData | Set the alert description | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/host/hosts_details_by_port.lua

**Get the hosts serving a port**

**Description:** The hosts serving a server port in the live flows (ip, name, vlan_id, mac, mac_manufacturer, flows, score, tot_traffic), paged (recordsTotal). A missing or stale application/port falls back to the first available one: the answer has the values used (protocol, application, port) and the options of the page filters, counted on all the hosts of the port: applications [{id, name}], ports [{port, n_hosts}] of the application, vlans [{id, name, count}], manufacturers [{name, count}]. Enterprise L.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `protocol` | query | Layer 4 protocol: 6 (TCP, default) or 17 (UDP) | integer |
| `application` | query | nDPI application, &lt;master>.&lt;app> or &lt;master> (e.g. 7.26, 91); default: the first one by name | string |
| `port` | query | Server port; default: the first port of the application | integer |
| `vlan_id` | query | Only the hosts of this VLAN | integer |
| `manufacturer` | query | Only the hosts with this MAC manufacturer | string |
| `sort` | query | Sort column: ip, name, vlan_id, mac, mac_manufacturer, score, flows, tot_traffic | string |
| `order` | query | asc or desc | string |
| `start` | query | First row (paging) | integer |
| `length` | query | Number of rows (paging, default 10) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (no Enterprise L); `-5` INVALID_ARGUMENTS

<a id="Alerts"></a>

## Alerts

### GET /lua/pro/rest/v2/acknowledge/snmp/device/alerts.lua

**Acknowledge SNMP device alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge SNMP device historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/add/alert/exclusion.lua

**Add an alert exclusion**

**Description:** Add an alert exclusion

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `type` | query | Type of the host to exclude (currently available: 'host', 'domain', 'certificate') | string |
| `alert_addr` | query | Host IP of the address to exclude (with type: 'host') | string |
| `alert_domain` | query | Domain to exclude (with type 'host') | string |
| `alert_certificate` | query | Certificate to exclude (with type 'certificate') | string |
| `subdir` | query | Type of alert to exclude (currently available: 'flow' or 'host' | string |
| `flow_alert_key` | query | Flow alert identifier | string |
| `host_alert_key` | query | Host alert identifier | string |
| `delete_alerts` | query | Return true to delete the excluded alerts, false otherwise | boolean |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/pro/rest/v2/add/device/exclusion.lua

**Authorize devices**

**Description:** Set to authorized the listed devices (MAC addresses) already seen by the Device/MAC Address Tracking. Enterprise M, administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not an administrator or no Enterprise M license); `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/delete/alert/exclusion.lua

**Delete an alert exclusion**

**Description:** Delete an alert exclusion

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `type` | query | Type of the host to exclude (currently available: 'host', 'domain', 'certificate') | string |
| `alert_addr` | query | Host IP of the address to exclude (with type: 'host') | string |
| `alert_domain` | query | Domain to exclude (with type 'host') | string |
| `alert_certificate` | query | Certificate to exclude (with type 'certificate') | string |
| `subdir` | query | Type of alert to exclude (currently available: 'flow' or 'host' | string |
| `flow_alert_key` | query | Flow alert identifier | string |
| `host_alert_key` | query | Host alert identifier | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/delete/all/alert/exclusions.lua

**Delete all alert exclusions**

**Description:** Delete all configured host or flow alert exclusions for a specific host

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `type` | query | Either 'host' or 'flow' | string |
| `host` | query | The IP address of the host | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/delete/device/exclusion.lua

**Remove a device**

**Description:** Remove a device (or all of them) from the Device/MAC Address Tracking: if it connects again it is unauthorized. Enterprise M, administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not an administrator or no Enterprise M license); `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/delete/snmp/device/alerts.lua

**Delete SNMP device alerts**

**Description:** Delete SNMP device alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/edit/device/exclusion.lua

**Edit a device**

**Description:** Edit the status of a device (or of all of them) of the Device/MAC Address Tracking. Enterprise M, administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not an administrator or no Enterprise M license); `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/all/alert/top.lua

**Get all alert stats**

**Description:** Get all alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | Start time (epoch) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/am_host/alert/top.lua

**Get Active Monitoring alert stats**

**Description:** Get Active Monitoring alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/device/exclusion.lua

**List of tracked devices**

**Description:** Devices (MAC addresses) seen by the Device/MAC Address Tracking, with their status. Enterprise M, administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `start` | query | First row (paging) | integer |
| `length` | query | Number of rows (default: all) | integer |
| `sort` | query |  | string |
| `order` | query |  | string |
| `map_search` | query | Text searched in the MAC address and manufacturer | string |

**Responses**

`0` OK: rsp = [{ mac, name?, ip? (first host with this MAC), num_hosts, manufacturer, status (allowed|denied|undecided), trigger_alert (bool), first_seen, last_seen (epoch), is_online }], recordsTotal; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not an administrator or no Enterprise M license)

### GET /lua/pro/rest/v2/get/domain/alert/exclusions.lua

**Get domain alert exclusions**

**Description:** Get domain alert exclusions

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/flow/alert/top.lua

**Get flow alert stats**

**Description:** Get flow alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/alert/preset/consts.lua

**Get the alert query presets**

**Description:** The query presets of an alert page: [{id: 'builtin', list}, {id: 'queries', list}] (empty when the page has none). Enterprise L.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `page` | query | Alert page (all, host, flow, ...) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED: no Enterprise L license or no alerts capability; `-5` INVALID_ARGUMENTS: unknown page

### GET /lua/pro/rest/v2/charts/alert/analysis.lua

**Get flow alerts bubble chart data**

**Description:** Flow alerts of the last timeframe grouped by client/server/alert type (at most 100 groups): one series per alert type (or one series for the score modes), each point x/y/z (z = bubble radius) with meta.label and meta.url_query (filters for /lua/alert_stats.lua). Enterprise, requires the alerts capability

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `bubble_mode` | query | Grouping: 0 score client/server, 1 alert type client/server, 2 alert type client, 3 alert type server, 4 score client, 5 score server (default 0) | integer |
| `timeframe` | query | Seconds back from now (default 3600) | integer |
| `vlan` | query | VLAN ID (empty: all VLANs) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/alert/graph/alerts.lua

**Get flow alerts graph edges**

**Description:** Historical flow alerts aggregated by client, server and alert type (ClickHouse, one table scan, the 2000 groups with the highest total score): src/dst IP, name, country, ASN, local flag, alert (id and label), alerts_count, total_score, severity_id and severity_color (highest severity of the group), first_seen and last_seen (epoch). Enterprise L or nEdge Enterprise, requires the historical flows capability

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `score` | query | Score (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `status` | query | Alert status: 'any' to include all the alerts, otherwise only the ones requiring attention | string |
| `cli_ip` | query | Client IP (format: 'ip;eq', op: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'ip;eq', op: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR (ClickHouse not enabled)

### GET /lua/pro/rest/v2/get/alert/graph/host_info.lua

**Get flow alerts summary of a host**

**Description:** Historical flow alerts of a host (ClickHouse): host_info.info (ip, name, country, ASN) and host_info.client / host_info.server (first/last seen, alerts_count, total_score, total_traffic_bytes); severity_info.client / severity_info.server: severity distribution in percent. Enterprise L or nEdge Enterprise, requires the historical flows capability

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `ip` | query | Host IP address | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-59` MISSING_PARAMETERS; `-6` INTERNAL_ERROR (ClickHouse not enabled)

### GET /lua/pro/rest/v2/get/host/alert/top.lua

**Get host alert stats**

**Description:** Get host alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/interface/alert/top.lua

**Get interface alert stats**

**Description:** Get interface alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `subtype` | query | Alert subtype | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/mac/alert/top.lua

**Get MAC alert stats**

**Description:** Get MAC alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/network/alert/top.lua

**Get network alert stats**

**Description:** Get network alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/sflowdevice/stats.lua

**Get sFlow device stats**

**Description:** get sFlow device stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `ip` | query | The IP address of the device | string |
| `ifIdx` | query | The interface index | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/sflowdevices/stats.lua

**Get sFlow devices stats**

**Description:** get sFlow devices stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/alert/list.lua

**Get SNMP device alerts list**

**Description:** Get SNMP device alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/alert/top.lua

**Get SNMP device alert stats**

**Description:** Get SNMP device alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/alert/ts.lua

**Get SNMP device alerts timeseries**

**Description:** Get SNMP device alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/system/alert/top.lua

**Get system alert stats**

**Description:** Get system alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/user/alert/top.lua

**Get user alert stats**

**Description:** Get user alert stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/am_host/alerts.lua

**Acknowledge Active Monitoring alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge Active Monitoring historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/flow/alerts.lua

**Acknowledge flow alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge flow historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/host/alerts.lua

**Acknowledge host alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge host historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/interface/alerts.lua

**Acknowledge interface alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge interface historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `subtype` | query | Alert subtype | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/mac/alerts.lua

**Acknowledge MAC alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge MAC historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/network/alerts.lua

**Acknowledge network alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge network historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/system/alerts.lua

**Acknowledge system alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge system historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/acknowledge/user/alerts.lua

**Acknowledge user alerts**

**Description:** DEPRECATED: alerts are acknowledged through the issues (edit/issue/acknowledge.lua, Enterprise XXL+). Acknowledge user historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `label` | query | Describe why the alert was ackowledge, it can be an empty string | string |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `row_id` | query | Alert identifier of the exact alert | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/all/alerts.lua

**Delete all alerts**

**Description:** Delete all historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/am_host/alerts.lua

**Delete active monitoring hosts alerts**

**Description:** Delete active monitoring hosts historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/flow/alerts.lua

**Delete flow alerts**

**Description:** Delete flow historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/host/alerts.lua

**Delete host alerts**

**Description:** Delete historical host alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/host/new_devices.lua

**Delete all new devices**

**Description:** Delete all new devices learned by ntopng

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v2/delete/interface/alerts.lua

**Delete interface alerts**

**Description:** Delete historical interface alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `subtype` | query | Alert subtype | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/mac/alerts.lua

**Delete MAC alerts**

**Description:** Delete MAC historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/network/alerts.lua

**Delete network alerts**

**Description:** Delete historical network alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/system/alerts.lua

**Delete system alerts**

**Description:** Delete system historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/delete/user/alerts.lua

**Delete user alerts**

**Description:** Delete user historical alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/alert/filter/consts.lua

**Get available alert filters**

**Description:** Given a specific alert type (flow, host, ...) return the available filters

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `page` | query | Alert Page (all, interface, flow, host, network, as, snmp_device, mac, user, am_host, system), default all | string |

**Responses**

`0` OK; `-3` NOT_GRANTED: the user has no alerts capability

### GET /lua/rest/v2/get/alert/severity/consts.lua

**Get alert severity constants**

**Description:** Alert severity string and integer severity id for each defined severity

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v2/get/alert/severity/counters.lua

**Get alert counters by severity**

**Description:** Alert severity counters in descending order

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `status` | query | Status filter (historical, historical-flows) | string |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | Start time (epoch) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/alert/type/consts.lua

**Get alert type constants**

**Description:** Alert type string and integer alert key for each defined alert

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v2/get/alert/type/counters.lua

**Get alert counters by type**

**Description:** Alert type counters indescending order

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `status` | query | Status filter (historical, historical-flows) | string |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/all/alert/list.lua

**Get all alerts list**

**Description:** Get all alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/all/alert/ts.lua

**Get all alerts timeseries**

**Description:** Get all alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | Start time (epoch) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/am_host/alert/list.lua

**Get Active Monitoring alerts list**

**Description:** Get Active Monitoring alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/am_host/alert/ts.lua

**Get Active Monitoring alerts timeseries**

**Description:** Get Active Monitoring alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/flow/alert/list.lua

**Get flow alerts list**

**Description:** Get flow alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `custom_script` | query | Title of a custom flow script that triggered the alert, with operator: &lt;title>;eq, &lt;title>;neq, &lt;text>;in (title contains it), &lt;text>;nin. Matches any of the scripts of the custom alert, also when it is not the main alert of the flow | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/flow/alert/ts.lua

**Get flow alerts timeseries**

**Description:** Get flow alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/flow/alert/geomap.lua

**Get flow alerts by country**

**Description:** Flow alerts aggregated per host (client and server) and per country (GeoIP), with the same filters as the flow alerts list. Requires GeoIP and ClickHouse.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `status` | query | Alerts status: 'historical' (require attention, default), 'engaged' or 'any' | string |
| `alert_id` | query | Alert type (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `severity` | query | Severity (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `score` | query | Score (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `cli_ip` | query | Client IP (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `srv_ip` | query | Server IP (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED: no alerts capability or GeoIP not available; `-6` INTERNAL_ERROR: ClickHouse not enabled

### GET /lua/rest/v2/get/flow/traffic_stats.lua

**Get traffic stats for active flows**

**Description:** Get traffic stats for active flows

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/host/alert/list.lua

**Get host alerts list**

**Description:** Get host alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/host/alert/ts.lua

**Get host alerts timeseries**

**Description:** Get host alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/host/alert/geomap.lua

**Get host alerts by country**

**Description:** Host alerts aggregated per host and per country (GeoIP), with the same filters as the host alerts list. Requires GeoIP and ClickHouse.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `status` | query | Alerts status: 'historical' (require attention, default), 'engaged' or 'any' | string |
| `alert_id` | query | Alert type (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `severity` | query | Severity (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `score` | query | Score (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `ip` | query | Host IP (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED: no alerts capability or GeoIP not available; `-6` INTERNAL_ERROR: ClickHouse not enabled

### GET /lua/rest/v2/get/interface/alert/list.lua

**Get interface alerts list**

**Description:** Get interface alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `subtype` | query | Alert subtype | string |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/interface/alert/ts.lua

**Get interface alerts timeseries**

**Description:** Get interface alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `subtype` | query | Alert subtype | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/mac/alert/list.lua

**Get MAC alerts list**

**Description:** Get MAC alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/mac/alert/ts.lua

**Get MAC alerts timeseries**

**Description:** Get MAC alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/network/alert/list.lua

**Get network alerts list**

**Description:** Get network alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/network/alert/ts.lua

**Get network alerts timeseries**

**Description:** Get network alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/as/alert/list.lua

**Get AS alerts list**

**Description:** Get the alerts of the Autonomous Systems

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `start` | query | Starting record | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `status` | query | Alerts status: 'historical' (require attention, default), 'engaged' or 'any' | string |
| `alert_id` | query | Alert type (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `severity` | query | Severity (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `score` | query | Score (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `asn` | query | Autonomous System number (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `format` | query | Format of the return data: 'json' (default) or 'txt' (CSV) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED: the user has no alerts capability

### GET /lua/rest/v2/get/as/alert/ts.lua

**Get AS alerts timeseries**

**Description:** Get the number of AS alerts over time, by severity

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `status` | query | Alerts status: 'historical' (require attention, default), 'engaged' or 'any' | string |
| `alert_id` | query | Alert type (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `severity` | query | Severity (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `score` | query | Score (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |
| `asn` | query | Autonomous System number (format: 'value;op', op: 'eq', 'neq', 'lt', 'lte', 'gt', 'gte') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED: the user has no alerts capability

### GET /lua/rest/v2/get/system/alert/list.lua

**Get system alerts list**

**Description:** Get system alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/system/alert/ts.lua

**Get system alerts timeseries**

**Description:** Get system alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/user/alert/list.lua

**Get user alerts list**

**Description:** Get user alerts list

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). recordsTotal is the number of records matching the filters: read the others with start and length, or download all of them with format=txt (CSV, ClickHouse only, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `format` | query | Format of the return data (json or txt) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/user/alert/ts.lua

**Get user alerts timeseries**

**Description:** Get user alerts timeseries

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | integer |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/alert/groups.lua

**Alert groups**

**Description:** Alerts grouped by one dimension (issue details), on the Alert Explorer stores (ClickHouse or SQLite) merged with the live alerts in memory (engaged host alerts, active flows with an alert). Any Alert Explorer filter (e.g. alert_id=79;eq, ip=192.168.1.1;eq, cli_ip, srv_ip) narrows the alerts; each group returns key, label, count, max_severity, max_score, first_seen, last_seen, families, the distinct hosts and the filters that select it in the Alert Explorer. Enterprise L+ only, with the issues enabled, and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current one) | integer |
| `epoch_begin` | query | Start of the time range (epoch seconds) | integer |
| `epoch_end` | query | End of the time range (epoch seconds) | integer |
| `group_by` | query | Dimension of the groups (default alert_id) | string |
| `page` | query | Alert family: only its alerts (default: flow and host alerts) | string |
| `status` | query | Alert status: historical (require attention, default), acknowledged or any | string |
| `sort` | query | Order of the groups (default priority) | string |
| `order` | query | Direction of the sort (default desc) | string |
| `limit` | query | Maximum number of groups (default 50, max 500) | integer |
| `episodes` | query | 0 to skip the episodes count (ClickHouse only, default 1) | integer |
| `episode_gap` | query | Maximum pause (seconds) between alerts of the same episode (default 900) | integer |
| `totals` | query | 1 to also return the totals of the grouping | integer |
| `strict` | query | 0 to match also the flows where the alert_id filter type is only a secondary alert, as the Alert Explorer (default 1: predominant alert only, so that child groups add up to their parent). Live flows match their predominant alert only | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (not Enterprise L+, feature not enabled or no alerts capability); `-5` INVALID_ARGUMENTS (time range, page or group_by); `-6` INTERNAL_ERROR

<a id="Issues"></a>

## Issues

### GET /lua/pro/rest/v2/get/issue/list.lua

**List issues**

**Description:** List the issues of a view, with filters, sorting and paging. Each record has issue_id, status (open|resolved), severity {id, label}, alert {id, name}, entity {id, label, value, name, host, role, url (host and flow issues: the host page on the first interface where the issue has been seen)}, ifids, interfaces [{id, name}] (where the issue has been seen), first_seen, last_seen, resolved_at, duration, signal_count, score (highest score of the alerts), total_score (sum of the scores of the alerts), peers_count, peers_sample, reopen_count, resolve_policy (on_release|quiet_period|manual), auto_resolve_at (open quiet_period issues: when resolved unless new alerts arrive), resolution, ack_user, ack_tstamp, assignee, suppressed, suppressed_until, tags [{id, name, color}] (union of the tags of the alerts of the issue, host and flow alerts only), alerts_url. The total is in recordsTotal. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `view` | query | problems (open issues, default), recent (resolved in the last 24 hours) or history (all the issues active in epoch_begin..epoch_end) | string |
| `epoch_begin` | query | Start time (epoch, view history only) | integer |
| `epoch_end` | query | End time (epoch, view history only) | integer |
| `severity` | query | Severity identifiers, comma separated (e.g. '5' or '5;eq,6;eq') | string |
| `alert_id` | query | Alert type identifiers, comma separated | string |
| `entity_id` | query | Alert entity identifiers, comma separated (e.g. 1 host, 4 flow) | string |
| `assignee` | query | Users the issues are assigned to, comma-separated (~: unassigned) | string |
| `tag` | query | Tag ids (0-63), comma-separated: the issues with one of the tags (tags of their alerts) | string |
| `suppressed` | query | Open issues: 1 the suppressed issues, 0 the not suppressed ones (default), 0,1 both | string |
| `resolve_policy` | query | Open issues: comma-separated ways they are resolved: 0 when the alert ends, 1 after 24 hours without alerts, 2 only by a user | string |
| `opened_within` | query | Only the issues first seen in the last seconds (e.g. 3600). Heatmap: also its time window (3600, 86400 or 172800, the default) | integer |
| `map_search` | query | Text searched in the entity (e.g. part of an IP), or an issue ID (e.g. 1573 or #1573) | string |
| `host` | query | Host (IP or IP@VLAN): only the issues of the host and the flow issues about it | string |
| `alert_category` | query | Alert categories, comma-separated | string |
| `mitre_tactic` | query | MITRE tactic ids of the alert types, comma-separated (0: no tactic) | string |
| `problem` | query | Alert types as &lt;alert entity id>:&lt;alert id>, comma-separated (e.g. 4:102,1:3) | string |
| `issue_entity` | query | Entity of the issues as &lt;alert entity id>\|&lt;entity value> (e.g. 0\|12 for interface 12) | string |
| `issue_peer` | query | Peer of the issues: an IP (the issues whose only peer is it), * (the issues with several peers) or ~ (the issues without peers) | string |
| `show_suppressed` | query | View problems: include the suppressed issues (default false) | boolean |
| `only_suppressed` | query | View problems: only the suppressed issues (default false) | boolean |
| `start` | query | First record (default 0) | integer |
| `length` | query | Number of records (default 10, max 500) | integer |
| `sort` | query | Sort column: issue_id, severity, score, first_seen, last_seen (default), resolved_at, signal_count, total_score, peers_count, alert_id, entity_val | string |
| `order` | query | asc or desc (default) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (unknown view)

### GET /lua/pro/rest/v2/get/issue/counters.lua

**Issue counters**

**Description:** Number of open (not suppressed) problems (problems) and by severity (problems_by_severity), of the issues of each view (views.problems, views.recent) and of the suppressed problems (suppressed). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Host (IP or IP@VLAN): only the issues of the host and the flow issues about it | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/issue/stats.lua

**Issue manager statistics**

**Description:** Internal statistics of the issue manager: loaded, issues in memory (num_open, num_recent, num_in_memory), pending writes (num_unsaved, num_pending_events, num_pending_notifications), num_signals, num_tracked_flows, dropped events and notifications, writer_since, and the queue of the ClickHouse flow alerts (flow_alert_queue_len, flow_alert_queue_bytes, num_flow_alerts_queued, num_flow_alert_drops, num_flow_alerts_processed, last_flow_alert_batch_alerts, last_flow_alert_batch_msec). Enterprise XXL+ only, requires alerts enabled. Administrators only.

**Produces:** `application/json`

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED (not an administrator)

### GET /lua/pro/rest/v2/get/issue/facets.lua

**Issue facets**

**Description:** For each facet (entity_id, severity, alert_category, mitre_tactic, problem, assignee, tag: all the tags, those without issues last with count 0, suppressed and resolve_policy: problems view only), the number of issues of each value (at most 12 except tag, the largest first; severities the most severe first) among the issues matching the filters of the other facets. Values have a label, or a label_key to translate. Same filters of the issue list. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `view` | query | problems (open issues, default), recent (resolved in the last 24 hours) or history (all the issues active in epoch_begin..epoch_end) | string |
| `epoch_begin` | query | Start time (epoch, view history only) | integer |
| `epoch_end` | query | End time (epoch, view history only) | integer |
| `severity` | query | Severity identifiers, comma separated (e.g. '5' or '5;eq,6;eq') | string |
| `alert_id` | query | Alert type identifiers, comma separated | string |
| `entity_id` | query | Alert entity identifiers, comma separated (e.g. 1 host, 4 flow) | string |
| `assignee` | query | Users the issues are assigned to, comma-separated (~: unassigned) | string |
| `tag` | query | Tag ids (0-63), comma-separated: the issues with one of the tags (tags of their alerts) | string |
| `suppressed` | query | Open issues: 1 the suppressed issues, 0 the not suppressed ones (default), 0,1 both | string |
| `resolve_policy` | query | Open issues: comma-separated ways they are resolved: 0 when the alert ends, 1 after 24 hours without alerts, 2 only by a user | string |
| `opened_within` | query | Only the issues first seen in the last seconds (e.g. 3600). Heatmap: also its time window (3600, 86400 or 172800, the default) | integer |
| `map_search` | query | Text searched in the entity (e.g. part of an IP), or an issue ID (e.g. 1573 or #1573) | string |
| `host` | query | Host (IP or IP@VLAN): only the issues of the host and the flow issues about it | string |
| `alert_category` | query | Alert categories, comma-separated | string |
| `mitre_tactic` | query | MITRE tactic ids of the alert types, comma-separated (0: no tactic) | string |
| `problem` | query | Alert types as &lt;alert entity id>:&lt;alert id>, comma-separated (e.g. 4:102,1:3) | string |
| `show_suppressed` | query | View problems: include the suppressed issues (default false) | boolean |
| `only_suppressed` | query | View problems: only the suppressed issues (default false) | boolean |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (unknown view)

### GET /lua/pro/rest/v2/get/issue/groups.lua

**Issue groups**

**Description:** Issues grouped by one dimension (group_by), the most severe groups first, then the largest. Each group has key, label, entity (entity type label, problem and host groups only), count, max_severity, last_seen, signal_count, total_score (sum of the scores of the alerts) and params: the parameters to add to list.lua to get the issues of the group, or to this endpoint for a further level. has_more tells if there are more groups. Same filters of the issue list. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `group_by` | query | Dimension of the groups: problem (alert type), host, peer (the only peer, * several peers, ~ none), severity, alert_category, entity_id (alert family), mitre_tactic or assignee (each user: an issue assigned to several users is in the group of each of them) | string |
| `view` | query | problems (open issues, default), recent (resolved in the last 24 hours) or history (all the issues active in epoch_begin..epoch_end) | string |
| `epoch_begin` | query | Start time (epoch, view history only) | integer |
| `epoch_end` | query | End time (epoch, view history only) | integer |
| `severity` | query | Severity identifiers, comma separated (e.g. '5' or '5;eq,6;eq') | string |
| `alert_id` | query | Alert type identifiers, comma separated | string |
| `entity_id` | query | Alert entity identifiers, comma separated (e.g. 1 host, 4 flow) | string |
| `assignee` | query | Users the issues are assigned to, comma-separated (~: unassigned) | string |
| `tag` | query | Tag ids (0-63), comma-separated: the issues with one of the tags (tags of their alerts) | string |
| `suppressed` | query | Open issues: 1 the suppressed issues, 0 the not suppressed ones (default), 0,1 both | string |
| `resolve_policy` | query | Open issues: comma-separated ways they are resolved: 0 when the alert ends, 1 after 24 hours without alerts, 2 only by a user | string |
| `opened_within` | query | Only the issues first seen in the last seconds (e.g. 3600). Heatmap: also its time window (3600, 86400 or 172800, the default) | integer |
| `map_search` | query | Text searched in the entity (e.g. part of an IP), or an issue ID (e.g. 1573 or #1573) | string |
| `host` | query | Host (IP or IP@VLAN): only the issues of the host and the flow issues about it | string |
| `alert_category` | query | Alert categories, comma-separated | string |
| `mitre_tactic` | query | MITRE tactic ids of the alert types, comma-separated (0: no tactic) | string |
| `problem` | query | Alert types as &lt;alert entity id>:&lt;alert id>, comma-separated (e.g. 4:102,1:3) | string |
| `issue_entity` | query | Entity of the issues as &lt;alert entity id>\|&lt;entity value> (e.g. 0\|12 for interface 12) | string |
| `issue_peer` | query | Peer of the issues: an IP (the issues whose only peer is it), * (the issues with several peers) or ~ (the issues without peers) | string |
| `show_suppressed` | query | View problems: include the suppressed issues (default false) | boolean |
| `only_suppressed` | query | View problems: only the suppressed issues (default false) | boolean |
| `start` | query | First record (default 0) | integer |
| `length` | query | Number of records (default 10, max 500) | integer |
| `sort` | query | Sort column: severity (most severe issue of the group, default), count (number of issues), signal_count (number of alerts), total_score (sum of the scores of the alerts) | string |
| `order` | query | asc or desc (default) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (unknown view)

### GET /lua/pro/rest/v2/get/issue/heatmap.lua

**Issue heatmap**

**Description:** Issue activity in a time window (opened_within: 1 hour, 24 hours, or 48 hours by default), in slots of 1, 15 or 30 minutes: slot (seconds), begin and end (epochs) and cells, a list of { tstamp, severity, value, issues } where value is the number of issues opened, reopened or escalated to that severity in the slot (events) and issues the number of distinct issues, only for the severities from min_severity (the minimum severity of the alerts opening issues, Preferences > Alerts). Same filters of the issue list, except the view and its time range. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `severity` | query | Severity identifiers, comma separated (e.g. '5' or '5;eq,6;eq') | string |
| `alert_id` | query | Alert type identifiers, comma separated | string |
| `entity_id` | query | Alert entity identifiers, comma separated (e.g. 1 host, 4 flow) | string |
| `assignee` | query | Users the issues are assigned to, comma-separated (~: unassigned) | string |
| `tag` | query | Tag ids (0-63), comma-separated: the issues with one of the tags (tags of their alerts) | string |
| `suppressed` | query | Open issues: 1 the suppressed issues, 0 the not suppressed ones (default), 0,1 both | string |
| `resolve_policy` | query | Open issues: comma-separated ways they are resolved: 0 when the alert ends, 1 after 24 hours without alerts, 2 only by a user | string |
| `opened_within` | query | Only the issues first seen in the last seconds (e.g. 3600). Heatmap: also its time window (3600, 86400 or 172800, the default) | integer |
| `map_search` | query | Text searched in the entity (e.g. part of an IP), or an issue ID (e.g. 1573 or #1573) | string |
| `host` | query | Host (IP or IP@VLAN): only the issues of the host and the flow issues about it | string |
| `alert_category` | query | Alert categories, comma-separated | string |
| `mitre_tactic` | query | MITRE tactic ids of the alert types, comma-separated (0: no tactic) | string |
| `problem` | query | Alert types as &lt;alert entity id>:&lt;alert id>, comma-separated (e.g. 4:102,1:3) | string |
| `issue_entity` | query | Entity of the issues as &lt;alert entity id>\|&lt;entity value> (e.g. 0\|12 for interface 12) | string |
| `issue_peer` | query | Peer of the issues: an IP (the issues whose only peer is it), * (the issues with several peers) or ~ (the issues without peers) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (unknown view)

### GET /lua/pro/rest/v2/get/issue/details.lua

**Issue details**

**Description:** Details of an issue (same fields as get/issue/list.lua, plus alert.description: what the alert type means, from the check that triggers it, when it has one). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | query | Issue identifier | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND

### GET /lua/pro/rest/v2/get/issue/events.lua

**Issue timeline**

**Description:** Events of an issue, oldest first: tstamp, event (open, escalate, resolve, reopen, acknowledge, assign, comment, suppress), user, info (e.g. severities, resolution, assignee, comment text). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | query | Issue identifier | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/issue/signals.lua

**Issue alerts**

**Description:** Latest alerts (signals) of an issue, newest first. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | query | Issue identifier | integer |
| `length` | query | Number of alerts (default 20, max 100) | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND

### GET /lua/pro/rest/v2/get/issue/assignees.lua

**Issue assignees**

**Description:** Users an issue can be assigned to. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Produces:** `application/json`

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/edit/issue/acknowledge.lua

**Acknowledge an issue**

**Description:** Records that the current user is handling the issue. The acknowledgement is cleared when the severity rises or the issue is reopened. POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS: rsp.error tells why (not_open, not_resolved, newer_issue_open, expired)

### POST /lua/pro/rest/v2/edit/issue/assign.lua

**Assign an issue**

**Description:** Assigns the issue to a user (empty: unassigned). POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |
| `assignee` | formData | Usernames, comma-separated (the issue is assigned to all of them), empty to unassign | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS: rsp.error tells why (not_open, not_resolved, newer_issue_open, expired); `-24` USER_DOES_NOT_EXIST

### POST /lua/pro/rest/v2/edit/issue/comment.lua

**Comment an issue**

**Description:** Adds a comment to the issue timeline. POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |
| `comment` | formData | Comment text (max 4096 characters) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/edit/issue/group.lua

**Apply an action to a group of issues**

**Description:** Applies the same user action to all the issues matching the filters of get/issue/list.lua (e.g. the params of a group of get/issue/groups.lua), written once. The issues the action does not apply to (e.g. resolve on a resolved issue) are skipped and counted in skipped by error id (not_found, not_open, not_resolved, newer_issue_open). An optional comment is added to each changed issue; with action comment only the comment is added, to all the matching issues. The changes are written in batches of 500. A group larger than the maximum number of open issues (preference issues_max_open, 50000 by default, as resolve_all.lua) is refused (error too_many, rsp.max), never changed in part. POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `action` | formData | The action: acknowledge, assign, suppress, severity, resolve, reopen or comment | string |
| `issue_assignee` | formData | assign: comma-separated users, empty to unassign (assignee is the filter of the issues) | string |
| `duration` | formData | suppress: seconds, 0 to remove the suppression | integer |
| `issue_severity` | formData | severity: 3=notice, 4=warning, 5=error, 6=critical, 8=emergency (severity is the filter of the issues) | integer |
| `comment` | formData | Comment added to each changed issue (max 4096 characters), required with action comment | string |
| `view` | formData | problems (default), recent or history (with epoch_begin, epoch_end) | string |
| `host` | formData | Filter: IP or IP@VLAN. The other filters of get/issue/list.lua (problem, severity, entity_id, alert_category, mitre_tactic, assignee, tag, suppressed, resolve_policy, issue_peer, issue_entity, opened_within) are accepted too | string |

**Responses**

`0` OK: { matched (issues of the group), done (issues changed), skipped (error id -> number of issues) }; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.error too_many: more than rsp.max issues); `-6` INTERNAL_ERROR (the comment could not be written)

### POST /lua/pro/rest/v2/edit/issue/severity.lua

**Change the severity of an issue**

**Description:** Set the severity of an open issue (3=notice, 4=warning, 5=error, 6=critical, 8=emergency), e.g. to escalate it. A higher severity is an escalation: the acknowledgement is cleared and the recipients of the issues are notified. Later alerts more severe than the chosen severity still raise it. Recorded in the issue events (severity) with the user. Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |
| `severity` | formData | The severity: 3=notice, 4=warning, 5=error, 6=critical, 8=emergency | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS: rsp.error tells why (not_open, not_resolved, newer_issue_open, expired)

### POST /lua/pro/rest/v2/edit/issue/suppress.lua

**Suppress an issue**

**Description:** Suppresses the issue notifications for a time: the issue is hidden from the problems unless show_suppressed is set. POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |
| `duration` | formData | Seconds, 0 removes the suppression | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS: rsp.error tells why (not_open, not_resolved, newer_issue_open, expired)

### POST /lua/pro/rest/v2/edit/issue/resolve.lua

**Resolve an issue**

**Description:** Resolves an open issue (resolution manual), with an optional comment added to its timeline. POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |
| `comment` | formData | Comment added to the timeline of the issue when resolved (at most 4096 characters) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS: rsp.error tells why (not_open, not_resolved, newer_issue_open, expired); `-6` INTERNAL_ERROR (the issue was resolved, the comment could not be written)

### POST /lua/pro/rest/v2/edit/issue/resolve_all.lua

**Resolve all the issues matching the filters**

**Description:** Resolves all the open issues matching the filters of the issue list (view problems; same filters as get/issue/list.lua: entity_id, severity, alert_category, mitre_tactic, problem, assignee, tag, suppressed, resolve_policy, opened_within, map_search, host, issue_entity, issue_peer), as the Resolve All button of the issues page. Each one is resolved as by edit/issue/resolve.lua (resolution manual, recipients notified), with the optional comment added to its timeline. Answer: resolved (issues resolved) and matching (issues matching the filters; the others were resolved meantime). POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `view` | formData | problems (default, the only one accepted) | string |
| `severity` | formData | Comma-separated severity ids (e.g. 4,5); the other filters as in get/issue/list.lua | string |
| `comment` | formData | Comment added to the timeline of each issue resolved (at most 4096 characters) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (view other than problems, invalid filters); `-6` INTERNAL_ERROR (the issues were resolved, the comment could not be written)

### POST /lua/pro/rest/v2/edit/issue/reopen.lua

**Reopen an issue**

**Description:** Reopens a resolved issue: from then on it is resolved only by a user. POST (JSON or form data, CSRF checked). Enterprise XXL+ only, requires alerts enabled and the alerts capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `issue_id` | formData | Issue identifier | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (not Enterprise XXL+, alerts disabled or Issues preference off); `-3` NOT_GRANTED; `-1` NOT_FOUND; `-5` INVALID_ARGUMENTS: rsp.error tells why (not_open, not_resolved, newer_issue_open, expired)

<a id="Flows"></a>

## Flows

### POST /lua/pro/rest/v2/get/flow/nedge/block_flow.lua

**Drop the traffic of a live flow**

**Description:** Drops the traffic of an active flow (inline interfaces, e.g. nEdge). Administrators only. rsp.status: BLOCKED, NOTFOUND or NOTALLOWED.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/db/columns_info.lua

**Get Clickhouse available columns**

**Description:** Executes a query to the flows database and return all the available columns the DB has

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/flow/historical/overview.lua

**Get the details of a historical flow**

**Description:** One flow stored in ClickHouse: rsp.flow is the record (raw columns, e.g. SRC2DST_BYTES, IPV4_SRC_ADDR, CLIENT_NW_LATENCY_US), rsp.proto_info the decoded PROTOCOL_INFO_JSON (protocol fields, TCP flags analysis, QoE, exporters, BGP), rsp.info the formatted fields (host names, ports, AS, countries, pools, connection states) and rsp.ext what the server resolves: tags, MAC manufacturers, AS/site/exporter/observation point names, the issues (alert id, nDPI risk id, source, score, title, info, MITRE id and tactic), the additional exported fields and the protocol views of the flow (views: modbus, s7comm, profinet, bgp, hr_charts; view_reasons: view -> license or no_data for the views shown disabled). Needs ClickHouse and the historical flows permission; flows of hosts outside the allowed networks of the user are not found.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `row_id` | query | Row id of the flow (rowid of the historical flows list) | integer |
| `tstamp` | query | Timestamp of the flow (tstamp of the historical flows list) | integer |
| `instance_name` | query | ntopng instance that stored the flow (NTOPNG_INSTANCE_NAME) | string |
| `bgp` | query | true: also rsp.ext.bgp_info (BGP/BMP information of the peers) | boolean |
| `llm` | query | true: also rsp.ext.llm_flow_data (the flow for the nAnalyst assistant) | boolean |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/db/flows.lua

**Get flows data. Columns include (but are not limited to) IP_PROTOCOL_VERSION, FLOW_TIME, FIRST_SEEN, LAST_SEEN, VLAN_ID, PACKETS, TOTAL_BYTES, SRC2DST_BYTES, DST2SRC_BYTES, IPV4_SRC_ADDR, IPV4_DST_ADDR, IPV6_SRC_ADDR, IPV6_DST_ADDR, PROTOCOL, L7_PROTO.**

**Description:** Executes a query to the flows database

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `begin_time_clause` | query | Start time (epoch) | integer |
| `end_time_clause` | query | Start time (epoch) | integer |
| `select_clause` | query | Select clause (default: *) | string |
| `where_clause` | query | Where clause (default: none). IP values should be double-quoted and between parenthesis (e.g. IPV4_SRC_ADDR = ("192.168.1.1")). | string |
| `maxhits_clause` | query | Max hits (default: 10) | integer |
| `order_by_clause` | query | Order by clause (default: no order) | string |
| `group_by_clause` | query | Group by clause (default: no group) | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/db/topk_flows.lua

**Get Top-K flows data. Columns include (but are not limited to) IP_PROTOCOL_VERSION, FLOW_TIME, FIRST_SEEN, LAST_SEEN, VLAN_ID, PACKETS, TOTAL_BYTES, SRC2DST_BYTES, DST2SRC_BYTES, IPV4_SRC_ADDR, IPV4_DST_ADDR, IPV6_SRC_ADDR, IPV6_DST_ADDR, PROTOCOL, L7_PROTO**

**Description:** Executes a top-k query to the flows database

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `begin_time_clause` | query | Start time (epoch) | integer |
| `end_time_clause` | query | End time (epoch) | integer |
| `select_keys_clause` | query | Select comma-separated keys list (default: IPV4_SRC_ADDR,IPV4_DST_ADDR,L7_PROTO) | string |
| `select_values_clause` | query | Select value (default: BYTES) | string |
| `where_clause` | query | Where clause (default: none) | string |
| `topk_clause` | query | Top-K clause (default: SUM) | string |
| `approx_search` | query | Approximate search (default: true) | string |
| `maxhits_clause` | query | Max hits (default: 10) | integer |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/flow/live/overview.lua

**Get the details of a live flow**

**Description:** One active flow: rsp.flow is the flow as exported by the engine (raw keys, e.g. cli2srv.bytes, protos.tls.client_requested_server_name, tcp.nw_latency.3wh_client_rtt), rsp.ext what the server resolves: host names (cli_name, srv_name), VLAN alias, tags, AS/site/exporter/observation point names, the issues (alert id, nDPI risk id, source, score, i18n key of the title, info, MITRE id and tactic), SIP/RTP values, the additional exported fields with their description, the protocol views of the flow (views: modbus, bgp, s7comm, profinet) and the user capabilities (is_admin, can_disable_check). Flows of hosts outside the allowed networks of the user are not found.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `flow_key` | query | Flow key (key of the live flows list) | integer |
| `flow_hash_id` | query | Flow hash id (hash_id of the live flows list) | integer |
| `counters` | query | true: only rsp.flow and rsp.now (for polling the live values) | boolean |
| `bgp` | query | true: also rsp.ext.bgp_info (BGP/BMP information of the peers) | boolean |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/flow/active.lua

**Get active flows**

**Description:** List of active flows

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `currentPage` | query | Pagination: page (optional) | integer |
| `perPage` | query | Pagination: items per page (optional) | integer |
| `sortColumn` | query | Pagination: column for sorting (e.g. 'score') (optional) | string |
| `sortOrder` | query | Pagination: sorting order: 'asc' or 'desc' (optional) | string |
| `host` | query | Host address filter (optional) | string |
| `vlan` | query | VLAN ID filter (optional) | integer |
| `l4proto` | query | L4 protocol filter (optional) | string |
| `application` | query | Application protocol filter (optional) | string |
| `verbose` | query | Add more details including TCP stats (optional) | boolean |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/flow/l4/counters.lua

**Get flow counters for L4 protocols**

**Description:** Number of active flows per L4 protocol

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/flow/l7/counters.lua

**Get flow counters for L7 protocols**

**Description:** Number of active flows per L7 application protocol

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/flow/geomap.lua

**Get the active flows on the map**

**Description:** The hosts of the active flows placed by GeoIP (nodes: ip, label, lat, lng, country, protocols, connectionCount, status) and the flows between them (edges), at most 512 flows. Same filters of get/flow/active_list.lua (e.g. application, l4proto, flowhosts_type, status, vlan, host). Enterprise L with the GeoIP database.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `flowhosts_type` | query | Host filter, also ip_version_4 / ip_version_6 or a host (IP[@vlan]) | string |
| `application` | query | Application (nDPI id) | string |
| `l4proto` | query | Layer 4 protocol number | integer |
| `status` | query | Flow status / alert type | string |
| `vlan` | query | VLAN id | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (no Enterprise L or no GeoIP)

### GET /lua/rest/v2/get/flow/aggregated_live_flows.lua

**Get the active flows grouped by a criteria**

**Description:** The active flows of the interface grouped by application, client, server, client/server/port, host, AS... Each row has flows, tot_score, bytes_sent, bytes_rcvd, tot_traffic, num_clients, num_servers and the grouping keys (application { id, label }, client/server/host { ip, label, vlan_id, in_memory, is_alerted, flags }, srv_port, src_as/dst_as/transit_as, info). The criteria besides application_protocol, client, server, client_server_srv_port, client_server_srv_port_app_proto and host need Enterprise M.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `aggregation_criteria` | query | application_protocol (default), client, server, client_server, app_client_server_criteria, info, client_server_srv_port, client_server_srv_port_app_proto, src_as_dst_as, src_as_transit_as_dst_as, host | string |
| `start` | query | Index of the first row (paging) | integer |
| `length` | query | Number of rows (paging) | integer |
| `sort` | query | Column to sort by (e.g. flows, tot_traffic, tot_score) | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text to search | string |
| `host` | query | Only the flows of this host | string |
| `vlan_id` | query | VLAN id | integer |
| `status` | query | Flow status / alert filter | integer |
| `deviceIP` | query | Flow exporter IP | string |
| `ifIdx` | query | Exporter interface index | integer |
| `srv_port` | query | Only the flows with this server port | integer |
| `l4proto` | query | Only the flows with this L4 protocol ID (e.g. 6 = TCP) | integer |
| `application` | query | Only the flows with this nDPI protocol: 'master.app' IDs (e.g. 7.26) or a single ID | string |
| `inIfIdx` | query | Exporter input interface index | integer |
| `outIfIdx` | query | Exporter output interface index | integer |
| `host_locality` | query | With aggregation_criteria=host: local or remote | string |
| `site_id` | query | With aggregation_criteria=host: site id | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/flow/active_list.lua

**Get the active flows**

**Description:** The flows currently active on the interface, with paging, sorting and the same filters of the Live Flows page. Each flow carries client and server (ip, name, port, vlan, asn, country...), application, l4_proto, bytes, throughput, score, alerts, first_seen/last_seen, flow_swapped (true when the ntopng direction heuristics swapped client and server) and, on flow-based interfaces, the exporter (the router/switch that exported the flow) and its input/output interfaces; on view interfaces seen_on_interface { id, name } is the interface of the view where ntopng saw the flow. recordsTotal is the number of flows matching the filters.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `start` | query | Index of the first flow (paging) | integer |
| `length` | query | Number of flows to return (paging) | integer |
| `sort` | query | Column to sort by: protocol, score, first_seen, last_seen, duration, throughput, bytes, qoe, cli_asn, srv_asn, transit_asn, cli_asn_asnmode_disabled, srv_asn_asnmode_disabled, flow_exporter, in_index, out_index. Any other value sorts by throughput | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text to search in the flows | string |
| `application` | query | Application (nDPI id, or &lt;master>.&lt;app>) | string |
| `l4proto` | query | Layer 4 protocol number (e.g. 6 TCP, 17 UDP) | integer |
| `flowhosts_type` | query | local_only, remote_only, local_origin_remote_target, remote_origin_local_target, ip_version_4, ip_version_6 | string |
| `status` | query | normal, alerted, connecting, closed, error, or an alert type id | string |
| `traffic_type` | query | unicast, broadcast_multicast, one_way_unicast, one_way_broadcast_multicast | string |
| `host` | query | Flows of this host (IP[@vlan]) | string |
| `client` | query | Flows with this client | string |
| `server` | query | Flows with this server | string |
| `port` | query | Flows with this port | integer |
| `vlan` | query | VLAN id | integer |
| `network` | query | Local network id | integer |
| `host_pool_id` | query | Host pool id | integer |
| `site_id` | query | Site id | integer |
| `dst_asn` | query | Destination AS number | integer |
| `qoe` | query | Quality of Experience class, 0 (worst) to 5 (best) | string |
| `deviceIP` | query | Flow exporter IP | string |
| `inIfIdx` | query | Exporter input interface index | integer |
| `outIfIdx` | query | Exporter output interface index | integer |
| `interface_filter` | query | Sub-interface (view interfaces) | integer |
| `flow_risk` | query | nDPI flow risk id | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/host/server_ports.lua

**Get the server ports of the live flows**

**Description:** The server ports seen in the live flows of the interface for a layer 4 protocol: srv_port, l4_proto, proto_id (nDPI &lt;master>.&lt;app> or &lt;master>), l7_proto_name and n_hosts (servers using it). Enterprise L. Only the flows of the user allowed networks and host pools.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `protocol` | query | Layer 4 protocol: 6 (TCP) or 17 (UDP) | integer |
| `vlan_id` | query | VLAN id (default: all the VLANs) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (no Enterprise L); `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/vlan/live_ports.lua

**Get the server ports by VLAN (live)**

**Description:** Sankey of the live flows: nodes (node_id vlan_&lt;id> / port_&lt;port>, label, link) and links (VLAN -> server port, label = application, value = bytes, l4_proto, l7_proto, optional_info.link to the live flows), the links with the most traffic first; vlans [{id, name}]: all the VLANs with flows; max_entries_reached when cut at limit. Only the flows of the user allowed networks and host pools.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `vlan` | query | Only this VLAN | integer |
| `l4proto` | query | Layer 4 protocol number (default TCP and UDP) | integer |
| `limit` | query | Max number of links (default 35) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/vlan/historical_ports.lua

**Get the server ports by VLAN (historical)**

**Description:** Same answer of get/vlan/live_ports.lua from the historical flows (ClickHouse) of the last timeframe seconds, at most 35 links; links open the historical flows. vlans [{id, name}]: the VLANs of the links. Only the flows of the user allowed networks and host pools. Needs the historical flows capability (non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `timeframe` | query | Seconds before now (e.g. 3600) | integer |
| `vlan` | query | Only this VLAN | integer |
| `l4proto` | query | Layer 4 protocol number; empty or -1: TCP and UDP | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/flow/bgp/looking_glass.lua

**Get the BGP routes of an IP address**

**Description:** The routes of the BGP RIB entry of an IP address (BGP feed), one row per prefix and peer: prefix, asn (of the IP), peer, peer_name and peer_site (when known), is_best_path, peer_asn { asn, name }, origin, as_path [{ asn, name }], next_hop, med, local_pref and communities. An empty list when the IP is missing, invalid or has no route.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IPv4 or IPv6 address | string |

**Responses**

`0` OK

<a id="PCAP"></a>

## PCAP

### GET /lua/pro/rest/v2/get/db/filter/bpf.lua

**BPF filter generation**

**Description:** Convert tags used to extract data from the database into the equivalent BPF filter, suitable for traffic extraction

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7proto_master` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7cat` | query | Application category identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `flow_risk` | query | Flow risk identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `l4proto` | query | Transport protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `src2dst_dscp` | query | Client to Server DSCP identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `country` | query | Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_asn` | query | Client ASN identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_asn` | query | Server ASN identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_nw_latency` | query | Client network latency  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_nw_latency` | query | Server network latency  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `observation_point_id` | query | Observation point identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `src2dst_tcp_flags` | query | Client to Server TCP Flags (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `dst2src_tcp_flags` | query | Server to Client TCP Flags (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `mac` | query | MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_mac` | query | Client MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_mac` | query | Server MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `info` | query | Info field (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `bytes` | query | Total Bytes  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `packets` | query | Total Packets  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_proc_name` | query | Client process name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_proc_name` | query | Server process name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_user_name` | query | Client user name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_user_name` | query | Server user name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`FILE` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### GET /lua/rest/v2/get/pcap/live_extraction.lua

**Extract (live download) PCAP data from the traffic recorded with the continuous recording (n2disk)**

**Description:** Raw PCAP data is returned

**Produces:** `application/vnd.tcpdump.pcap`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `bpf_filter` | query | BPF filter | string |

**Responses**

`FILE` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### GET /lua/rest/v2/create/pcap/extraction/task.lua

**Schedule PCAP data extraction from traffic recorded with the continuous recording (n2disk). A job ID is returned to check the extraction status (see /lua/rest/v2/get/pcap/extraction/tasks.lua)**

**Description:** Job info is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `bpf_filter` | query | BPF filter | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/pcap/extraction/jobs.lua

**Read the PCAP extraction jobs of an interface (raw values)**

**Description:** Administrators only, with n2disk installed. Newest first: id, time, status (waiting, waiting_nospace, processing, completed, stopped, failed), error_code (failed), time_from, time_to, filter, chart_url, files (PCAP files to download with /lua/rest/v2/get/pcap/extraction/data.lua), extracted_pkts and extracted_bytes (completed).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### POST /lua/rest/v2/delete/pcap/extraction/job.lua

**Delete a PCAP extraction job and its files**

**Description:** Administrators only, with n2disk installed. job_id: a job of the interface; all=true instead: every job of the interface (the running ones are stopped).

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/set/pcap/extraction/stop_job.lua

**Stop a running PCAP extraction job**

**Description:** Administrators only, with n2disk installed. The PCAP extracted so far is kept (status stopped).

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/pcap/extraction/tasks.lua

**Read PCAP extraction jobs (scheduled with /lua/rest/v2/create/pcap/extraction/task.lua) information**

**Description:** DataTables format with formatted values (perPage, currentPage, sortColumn, sortOrder): {data, totalRows, ...}, no rc. Administrators only, with n2disk installed (else an empty answer). Raw values: /lua/rest/v2/get/pcap/extraction/jobs.lua

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/pcap/extraction/data.lua

**Download PCAP data extracted by a scheduled extraction task (scheduled with /lua/rest/v2/create/pcap/extraction/task.lua)**

**Description:** Raw PCAP data is returned

**Produces:** `application/vnd.tcpdump.pcap`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `job_id` | query | Job ID | integer |
| `file_id` | query | File ID (default 1) | integer |

**Responses**

`FILE` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### GET /lua/rest/v2/get/pcap/live_captures.lua

**Get the running live captures**

**Description:** Live captures (pcap downloads of live traffic) running on the interface: id, host (missing when the whole interface is captured), num_captured_packets, capture_max_pkts, capture_until (epoch). Needs the pcap download right

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED: the user cannot download pcap files; `-2` INVALID_INTERFACE: the user cannot access the interface

### POST /lua/rest/v2/delete/pcap/live_capture.lua

**Stop a live capture**

**Description:** Stops a running live capture of the interface. Administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | { ifid, capture_id } (capture_id: id returned by get/pcap/live_captures.lua) | object |

**Responses**

`0` OK; `-3` NOT_GRANTED: administrators only; `-5` INVALID_ARGUMENTS: ifid or capture_id missing; `-2` INVALID_INTERFACE: the user cannot access the interface

### GET /lua/rest/v2/get/pcap/live_traffic.lua

**Live traffic capture**

**Description:** Raw PCAP data is returned

**Produces:** `application/vnd.tcpdump.pcap`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `bpf_filter` | query | BPF filter | string |

**Responses**

`FILE` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

<a id="Users"></a>

## Users

### POST /lua/rest/v2/add/ntopng/user.lua

**Add ntopng user**

**Description:** Add a ntopng user

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |
| `full_name` | formData | Full name | string |
| `password` | formData | Password | string |
| `confirm_password` | formData | Confirmed password | string |
| `user_role` | formData | User role (unprivileged / administrator) | string |
| `allowed_networks` | formData | Allowed networks (e.g. 0.0.0.0/0,::/0) | string |
| `allowed_interface` | formData | Allowed interfaces (empty for all) | string |
| `add_user_language` | formData | Language (en, it, de, jp, pt, cz) | string |
| `allow_pcap_download` | formData | Allow PCAPs download (1 to allow) | string |
| `allow_historical_flows` | formData | Allow Historical Flows page (1 to allow, 0 to deny) | string |
| `allow_alerts` | formData | Allow Alerts page (1 to allow, 0 to deny) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-19` PASSWORD_MISMATCH; `-20` ADD_USER_FAILED; `-23` USER_ALREADY_EXISTING

### POST /lua/rest/v2/create/ntopng/session.lua

**Create a new ntopng user session Cookie**

**Description:** Generate a new user session to be used as session Cookie

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |
| `auth_session_duration` | formData | Session duration (seconds). Default: 0 (no expiration). | integer |

**Responses**

`-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/delete/ntopng/user.lua

**Delete ntopng user**

**Description:** Delete a ntopng user

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |

**Responses**

`-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-21` DELETE_USER_FAILED

### POST /lua/rest/v2/edit/ntopng/user.lua

**Edit a ntopng user**

**Description:** Edit an existing ntopng user

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |
| `full_name` | formData | Full name | string |
| `password` | formData | Password | string |
| `confirm_password` | formData | Confirmed password | string |
| `user_role` | formData | User role (unprivileged / administrator) | string |
| `allowed_networks` | formData | Allowed networks (e.g. 0.0.0.0/0,::/0) | string |
| `allowed_interface` | formData | Allowed interfaces (empty for all) | string |
| `user_language` | formData | Language (en, it, de, jp, pt, cz) | string |
| `allow_pcap_download` | formData | Allow PCAPs download (1 to allow) | string |
| `allow_historical_flows` | formData | Allow Historical Flows page (1 to allow, 0 to deny) | string |
| `allow_alerts` | formData | Allow Alerts page (1 to allow, 0 to deny) | string |

**Responses**

`-5` INVALID_ARGUMENTS; `-21` DELETE_USER_FAILED; `-23` USER_DOES_NOT_EXIST; `-24` EDIT_USER_FAILED

### GET /lua/rest/v2/get/ntopng/users.lua

**Read all configured ntopng users**

**Description:** Read all configured ntopng users

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Infrastructures"></a>

## Infrastructures

### POST /lua/pro/rest/v2/add/infrastructure/instance.lua

**Add a new infrastructure configuration**

**Description:** Add a new infrastructure configuration. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `url` | formData | The URL of the ntopng in the infrastructure (http or https, stored as scheme://host:port) | string |
| `alias` | formData | An alias for the infrastructure | string |
| `token` | formData | The REST API Token for the authentication | string |
| `rtt_threshold` | formData | RTT threshold of the active monitoring, in seconds (1-10) | integer |
| `bandwidth_threshold` | formData | Bandwidth threshold of the active monitoring, in Mbps (0-1000) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-34` INFRASTRUCTURE_INSTANCE_EMPTY_ALIAS; `-35` INFRASTRUCTURE_INSTANCE_EMPTY_URL; `-36` INFRASTRUCTURE_INSTANCE_EMPTY_TOKEN; `-37` INFRASTRUCTURE_INSTANCE_EMPTY_RTT_THRESHOLD; `-39` INFRASTRUCTURE_INSTANCE_SAME_ALIAS; `-40` INFRASTRUCTURE_INSTANCE_SAME_URL; `-41` INFRASTRUCTURE_INSTANCE_SAME_TOKEN; `-42` INFRASTRUCTURE_INSTANCE_ALREADY_EXISTING; `-47` INFRASTRUCTURE_INSTANCE_EMPTY_BANDWIDTH_THRESHOLD

### POST /lua/pro/rest/v2/check/infrastructure/config.lua

**Test an infrastructure configuration**

**Description:** Connects to the REST API of an ntopng in the infrastructure with the url and token: parameters in the JSON body (query string accepted for compatibility). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `url` | formData | The URL of the ntopng in the infrastructure | string |
| `token` | formData | The REST API Token for the authentication | string |

**Responses**

`0` OK; `-42` INFRASTRUCTURE_INSTANCE_ALREADY_EXISTING; `-43` INFRASTRUCTURE_INSTANCE_CHECK_FAILED; `-24` INFRASTRUCTURE_INSTANCE_CHECK_NOT_FOUND; `-45` INFRASTRUCTURE_INSTANCE_CHECK_INVALID_RESPONSE; `-46` INFRASTRUCTURE_INSTANCE_CHECK_AUTH_FAILED; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/delete/infrastructure/instance.lua

**Delete an existing infrastructure configuration**

**Description:** Delete an existing infrastructure configuration. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `instance_id` | formData | The ID of the infrastructure to delete | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-32` INFRASTRUCTURE_INSTANCE_NOT_FOUND; `-33` INFRASTRUCTURE_INSTANCE_EMPTY_ID

### POST /lua/pro/rest/v2/edit/infrastructure/instance.lua

**Edit an existing infrastructure configuration**

**Description:** Edit an existing infrastructure configuration. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `instance_id` | formData | The ID of the infrastructure configuration to edit | string |
| `url` | formData | The URL of the ntopng in the infrastructure (http or https, stored as scheme://host:port) | string |
| `alias` | formData | An alias for the infrastructure | string |
| `token` | formData | The REST API Token for the authentication | string |
| `rtt_threshold` | formData | RTT threshold of the active monitoring, in seconds (1-10) | integer |
| `bandwidth_threshold` | formData | Bandwidth threshold of the active monitoring, in Mbps (0-1000) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-32` INFRASTRUCTURE_INSTANCE_NOT_FOUND; `-33` INFRASTRUCTURE_INSTANCE_EMPTY_ID; `-34` INFRASTRUCTURE_INSTANCE_EMPTY_ALIAS; `-35` INFRASTRUCTURE_INSTANCE_EMPTY_URL; `-36` INFRASTRUCTURE_INSTANCE_EMPTY_TOKEN; `-37` INFRASTRUCTURE_INSTANCE_EMPTY_RTT_THRESHOLD; `-39` INFRASTRUCTURE_INSTANCE_SAME_ALIAS; `-40` INFRASTRUCTURE_INSTANCE_SAME_URL; `-41` INFRASTRUCTURE_INSTANCE_SAME_TOKEN; `-47` INFRASTRUCTURE_INSTANCE_EMPTY_BANDWIDTH_THRESHOLD

### GET /lua/pro/rest/v2/get/infrastructure/instance.lua

**Get one or all infrastructure configs**

**Description:** Get one or all infrastructure configs. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `instance_id` | query | ID of the infrastructure configuration (all of them when empty) | string |
| `stats` | query | Add the statistics collected by the active monitoring module | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-32` INFRASTRUCTURE_INSTANCE_NOT_FOUND

### GET /lua/rest/v2/export/infrastructure/config.lua

**Export the Infrastructure configurations as a JSON file**

**Description:** Export the configuration for the infrastructure configurations

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/import/infrastructure/config.lua

**Import the Infrastructure configuration providing a JSON file**

**Description:** Import the configuration for all infrastructure configurations

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### POST /lua/rest/v2/reset/infrastructure/config.lua

**Reset all infrastructure configurations**

**Description:** Reset all infrastructure configurations

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Health"></a>

## Health

### GET /lua/pro/rest/v2/get/system/health/clickhouse.lua

**Get Clickhouse Stats**

**Description:** ClickHouse status: version, health (green when a query works, else red), status (UP or DISABLED), size in bytes and rows of the flows (flows_size, flows_number), hourly flows (hourly_flows_size, hourly_flows_number) and alert tables (alerts_size, alerts_number), system_errors (last errors, already formatted with their date). Needs access to the system interface

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED: the user cannot access the system interface; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/system/health/influxdb.lua

**Get InfluxDB Stats**

**Description:** InfluxDB export status. With InfluxDB as timeseries driver: status UP, version, health (green, yellow while retrying failed exports, red while dropping points), exports, points_exported and, when the InfluxDB internal monitoring database is available, db_bytes, memory, num_series. Otherwise status DISABLED. Needs access to the system interface

**Produces:** `application/json`

**Responses**

`0` OK: { status, version?, health?, exports?, points_exported?, db_bytes?, memory?, num_series? }; `-3` NOT_GRANTED: the user cannot access the system interface; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/system/health/interfaces.lua

**Get interfaces stats**

**Description:** Get statistics of every active interfaces

**Produces:** `application/json`

**Responses**

`0` OK; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/system/health/interfaces_list.lua

**Get the counters of every interface**

**Description:** One record per monitored interface: ifid, name (alias if set), engaged_alerts, alerted_flows, local_hosts, remote_hosts, devices, flows and, since the last counters reset, bytes, packets, drops. Needs access to the system interface

**Produces:** `application/json`

**Responses**

`0` OK: [{ ifid, name, engaged_alerts, alerted_flows, local_hosts, remote_hosts, devices, flows, bytes, packets, drops }]; `-3` NOT_GRANTED: the user cannot access the system interface

### GET /lua/rest/v2/get/system/health/log.lua

**Get the last ntopng log lines**

**Description:** The last 33 lines of the ntopng log, newest first, as plain text. Needs access to the system interface; not available on OEM builds

**Produces:** `application/json`

**Responses**

`0` OK: [line]; `-3` NOT_GRANTED: the user cannot access the system interface

### GET /lua/rest/v2/get/system/health/redis.lua

**Get Redis Stats**

**Description:** Redis status: used memory (resident set size, bytes), number of keys (dbsize) and health (green, or red when the last persistence to disk failed). On Windows dbsize is missing and health is always green. Needs access to the system interface

**Produces:** `application/json`

**Responses**

`0` OK: { memory, dbsize, health }; `-3` NOT_GRANTED: the user cannot access the system interface; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/redis/redis_stats.lua

**Get Redis calls per command**

**Description:** Calls made by ntopng to Redis since startup, one record per command: { command: { key, name }, hits }. Needs access to the system interface

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED: the user cannot access the system interface

### GET /lua/rest/v2/get/redis/queues.lua

**Get the Redis queues**

**Description:** Redis lists used by ntopng as queues (per interface and of the system), one record per queue: { ifid, iface_name, queue_i18n, redis_key, length, max_length, fill_pct }. ifid is -1 (and iface_name missing) for the queues of the system; queue_i18n is the i18n key of the queue name; max_length and fill_pct are missing for the queues with no max length. Needs access to the system interface

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED: the user cannot access the system interface

### GET /lua/rest/v2/get/system/health/stats.lua

**Get system stats**

**Description:** Get statistics of the system on top of which ntopng is running

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED: the user cannot access the system interface; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/system/status.lua

**Get system status info**

**Description:** Get license information and resources used data

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v2/get/system/reload_ndpi.lua

**Reload nDPI and Blacklists**

**Description:** Reload nDPI (also the changes to the custom protocols) and all the enabled blacklists

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Configurations"></a>

## Configurations

### GET /lua/rest/v2/get/category/host_rule_context.lua

**Get the context of a custom host rule**

**Description:** For a server name or URL: the host name suggested for a custom host rule, the custom category that already matches it, and the nDPI categories and applications (applications only with a protos file) it can be added to. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Server name or URL (e.g. www.example.com) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/add/category/host_rule.lua

**Add a custom host rule**

**Description:** Adds a host to a custom category (applied at once) or to an application (written in the protos file, applied after a restart). Exactly one of category_id and application_id. rsp.restart_needed: true for an application. BAD_CONTENT: the host is already in the category. Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-8` BAD_CONTENT

### GET /lua/rest/v2/get/system/configurations/download_backup.lua

**Get system configuration automatic backup**

**Description:** Get on of the automatic system configurations backups

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch` | query | The epoch of the backup | integer |
| `download` | query | Download the backup or just retrive info | boolean |

**Responses**

`0` OK; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/system/configurations/list_available_backups.lua

**Get system configurations automatic backups**

**Description:** Get list of automatic system configurations backups

**Produces:** `application/json`

**Responses**

`0` OK; `-6` INTERNAL_ERROR

<a id="Vulnerability Scan"></a>

## Vulnerability Scan

### GET /lua/pro/rest/v2/get/host/scan_port_list.lua

**Open ports found by the scans**

**Description:** Open ports found by the last scans, with the hosts that have them open. Enterprise L. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch_end` | query | Report time: the ports as they were in that report | integer |
| `protocol` | query | Only this L4 protocol (id) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only)

### POST /lua/rest/v2/delete/host/delete_host_to_scan.lua

**Remove hosts to scan**

**Description:** Remove one host (host + scan_type), all the hosts (delete_all_scan_hosts=true) or the hosts whose last scan failed (delete_failed_scan_hosts=true). Write: JSON POST body with the csrf (or Basic auth), parameters in the query string are ignored. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | Host address | string |
| `scan_type` | formData | Scan type: tcp_portscan, udp_portscan, ipv4_netscan (the ids of get/host/active_scan_type_list.lua) | string |
| `delete_all_scan_hosts` | formData | true: remove every host | boolean |
| `delete_failed_scan_hosts` | formData | true: remove the hosts whose last scan failed | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-6` INTERNAL_ERROR; `-8` BAD_CONTENT

### GET /lua/rest/v2/get/host/active_scan_result.lua

**Result of a host scan**

**Description:** The nmap output of the last scan of a host: as JSON (rsp.rsp) with scan_return_result=true, else as a text file download. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Host address | string |
| `scan_type` | query | Scan type: tcp_portscan, udp_portscan, ipv4_netscan (the ids of get/host/active_scan_type_list.lua) | string |
| `epoch` | query | Time of the scan (with ClickHouse the result is read from the database) | integer |
| `scan_return_result` | query | true: JSON answer, false: file download | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/active_scan_status.lua

**Scans in progress**

**Description:** rsp.rsp: { total: hosts to scan, total_in_progress: scheduled or being scanned, total_in_success }. Admin only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only)

### POST /lua/pro/rest/v2/delete/vs/report.lua

**Delete a stored report**

**Description:** Delete a report (ClickHouse). Write: JSON POST body with the csrf (or Basic auth), parameters in the query string are ignored. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch` | formData | Report time (epoch of the list) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/pro/rest/v2/edit/vs/report.lua

**Rename a stored report**

**Description:** Rename a report (ClickHouse). Write: JSON POST body with the csrf (or Basic auth), parameters in the query string are ignored. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch_end` | formData | Report time (epoch of the list) | integer |
| `report_title` | formData | New name: spaces as _ | string |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/vs/report_list.lua

**List the stored reports**

**Description:** Reports saved at the end of each periodic scan (ClickHouse): name, epoch, report_date, tcp_ports, udp_ports, num_hosts. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `map_search` | query | Only the reports whose name contains this text | string |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only)

### POST /lua/rest/v2/add/host/to_scan.lua

**Add a host to scan**

**Description:** Add a host (or the active hosts of a network with vs_cidr, or a network scan with ipv4_netscan) to the Active Scan list and schedule its first scan; is_edit=true changes an entry. rsp.rsp: 1 added/updated, 2 already in the list, 3 no active host in the network. Write: JSON POST body with the csrf (or Basic auth), parameters in the query string are ignored. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | Host IP address (IPv4 or IPv6) | string |
| `scan_type` | formData | Scan type: tcp_portscan, udp_portscan, ipv4_netscan (the ids of get/host/active_scan_type_list.lua) | string |
| `scan_ports` | formData | Ports to scan, comma separated or ranges (e.g. 22,80,1000-2000); empty: all | string |
| `scan_frequency` | formData | Periodic scan (Enterprise L): disabled, 1day (every night), 1week (every week) | string |
| `vs_cidr` | formData | Network prefix length: 24-30, 32 or 128 | integer |
| `discovered_host_scan_type` | formData | ipv4_netscan: scan types to run on the discovered hosts, comma separated | string |
| `is_edit` | formData | true: change an existing entry | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-6` INTERNAL_ERROR; `-8` BAD_CONTENT; `-2` NOT_ENABLED (nmap is not installed)

### POST /lua/rest/v2/edit/host/update_va_scan_period.lua

**Change the periodicity of every scan**

**Description:** Set the same periodic scan on all the hosts of the list (Enterprise L). Write: JSON POST body with the csrf (or Basic auth), parameters in the query string are ignored. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `scan_frequency` | formData | disabled, 1day (every night) or 1week (every week) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/exec/host/schedule_active_scan.lua

**Scan now**

**Description:** Schedule the scan of one host of the list (scan_single_host=true) or of all of them. Write: JSON POST body with the csrf (or Basic auth), parameters in the query string are ignored. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `scan_single_host` | formData | true: one host, false: every host | boolean |
| `host` | formData | Host IP address (scan_single_host=true) | string |
| `scan_type` | formData | Scan type: tcp_portscan, udp_portscan, ipv4_netscan (the ids of get/host/active_scan_type_list.lua) (scan_single_host=true) | string |
| `scan_ports` | formData | Ports to scan | string |
| `scan_id` | formData | Id of the list entry | string |
| `vs_cidr` | formData | Network prefix length | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-2` NOT_ENABLED (nmap is not installed)

### GET /lua/rest/v2/get/host/to_scan_list.lua

**List the hosts to scan**

**Description:** Hosts and networks of the Active Scan list, with the status and result (open ports) of their last scan. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `port` | query | Only the hosts with this port open | integer |
| `epoch_end` | query | Report time: the hosts as they were in that report | integer |
| `was_down` | query | Only the hosts that were down and are now up | boolean |
| `netscan_report` | query | Hosts discovered by the network scans | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only)

### GET /lua/rest/v2/get/host/active_scan_type_list.lua

**List the scan types**

**Description:** Scan types available on this system (they need nmap). rsp.rsp: [{ id }]: the page builds the labels. Admin only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only)

<a id="AI Dashboards"></a>

## AI Dashboards

### GET /lua/pro/rest/v2/get/dashboard/list.lua

**List the AI dashboards**

**Description:** List of the saved AI dashboards: [{ id, name, description }]. Administrators only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/dashboard/dashboard.lua

**Get an AI dashboard**

**Description:** Definition of a dashboard: { id, name, description, widgets: [{ id, type, title, config: { sql_query, unit, label_field, value_field, ... }, layout: { x, y, w, h } }] }. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `dashboard_id` | query | Dashboard id (letters, digits, '_' and '-'), as returned by get/dashboard/list.lua | string |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-1` NOT_FOUND

### GET /lua/pro/rest/v2/get/dashboard/widget_data.lua

**Get the data of a widget**

**Description:** Runs the SQL query of a saved widget on ClickHouse and returns its result, shaped for the widget type (e.g. stat: { value }). The placeholders $EPOCH_BEGIN$, $EPOCH_END$, $IFID$ and $FILTERS$ of the query are replaced with the parameters below; on the flows tables the flow filters (same parameters as the Historical Flows explorer, e.g. l7proto=7;eq) are applied too. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `dashboard_id` | query | Dashboard id | string |
| `widget_id` | query | Widget id, as in the dashboard definition | string |
| `epoch_begin` | query | Begin of the time range (epoch, seconds). Default: epoch_end - 24 hours | integer |
| `epoch_end` | query | End of the time range (epoch, seconds). Default: now | integer |
| `ifid` | query | Interface id. Default: the current interface | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR (query failed: the error is in rsp.error)

### POST /lua/pro/rest/v2/set/dashboard/dashboard.lua

**Create or update an AI dashboard**

**Description:** Creates a dashboard (id derived from the name) or, when dashboard_id matches an existing one, replaces it. Returns { success, id, dashboard }. The field names differ from the stored ones: dashboard_name (not name), widget_id (not id) and layout { pos_x, pos_y, grid_w, grid_h }. Widget types: timeseries, table, bar_chart, pie_chart, stat, heatmap, bubble_chart, sankey, chord. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `payload` | body | JSON body, e.g. { "dashboard_name": "Network overview", "description": "", "widgets": [{ "widget_id": "w1", "type": "stat", "title": "Flows", "config": { "sql_query": "SELECT count() AS value FROM flows WHERE FIRST_SEEN >= $EPOCH_BEGIN$ AND FIRST_SEEN &lt;= $EPOCH_END$ AND INTERFACE_ID = $IFID$ AND $FILTERS$", "value_field": "value", "unit": "number" }, "layout": { "pos_x": 0, "pos_y": 0, "grid_w": 4, "grid_h": 3 } }] }. Add "dashboard_id" to update an existing dashboard. | object |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-59` MISSING_PARAMETERS; `-8` BAD_CONTENT (invalid definition, the reason is in rsp.error)

### POST /lua/pro/rest/v2/delete/dashboard/dashboard.lua

**Delete an AI dashboard**

**Description:** Deletes a dashboard. Returns { success }. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `payload` | body | JSON body: { "dashboard_id": "network-overview" } (dashboard_id is also accepted as query parameter) | object |

**Responses**

`0` OK; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-1` NOT_FOUND; `-59` MISSING_PARAMETERS

<a id="Syslog Rules"></a>

## Syslog Rules

### GET /lua/pro/rest/v2/get/syslog/messages.lua

**Get the syslog messages**

**Description:** Syslog messages collected in ClickHouse, paginated: [{ ts, ip, hostname, facility, severity, app_name, message }], recordsTotal. Enterprise XL, administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch_begin` | query | Begin of the time range (epoch) | integer |
| `epoch_end` | query | End of the time range (epoch) | integer |
| `syslog_ip` | query | Only the messages sent by this IP | string |
| `syslog_severity` | query | Only this severity (0-7) | integer |
| `syslog_hostname` | query | Only this hostname | string |
| `syslog_app_name` | query | Only this application | string |
| `syslog_facility` | query | Only this facility | string |
| `map_search` | query | Text searched in message, IP, hostname, application, facility, severity | string |
| `start` | query | First record | integer |
| `length` | query | Number of records (max 500) | integer |
| `sort` | query | ts, ip, hostname, facility, severity, app_name, message | string |
| `order` | query | asc or desc | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/syslog/facets.lua

**Get the syslog facets**

**Description:** Most frequent values (max 15) of every facet with their message count: [{ id: severity|ip|hostname|app_name|facility, items: [{ value, count }] }]. The filter of a facet is not applied to the facet itself. Enterprise XL, administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch_begin` | query | Begin of the time range (epoch) | integer |
| `epoch_end` | query | End of the time range (epoch) | integer |
| `syslog_ip` | query | Only the messages sent by this IP | string |
| `syslog_severity` | query | Only this severity (0-7) | integer |
| `syslog_hostname` | query | Only this hostname | string |
| `syslog_app_name` | query | Only this application | string |
| `syslog_facility` | query | Only this facility | string |
| `map_search` | query | Text searched in message, IP, hostname, application, facility, severity | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/syslog/rules.lua

**List the syslog rules**

**Description:** Syslog collector rules, evaluated before a message is stored: the first matching rule wins and a message matching no rule is kept. Returns an array of { id, enabled, min_severity, max_severity, source, pattern, comment, updated_at }. Enterprise XL and administrators only.

**Produces:** `application/json`

**Responses**

`-3` NOT_GRANTED (Enterprise XL and administrators only); `-5` INVALID_ARGUMENTS; `0` OK

### POST /lua/pro/rest/v2/add/syslog/rule.lua

**Add a syslog rule**

**Description:** Adds a syslog rule. Fails if a rule with the same id already exists. Enterprise XL and administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `syslog_rule_id` | formData | Rule id (UUID, e.g. generated client side). For edit and delete it must identify an existing rule | string |
| `syslog_rule_enabled` | formData | 1 = rule enabled, 0 = disabled | integer |
| `syslog_rule_min_severity` | formData | Inclusive lower severity bound: 0 = Emergency, 1 = Alert, 2 = Critical, 3 = Error, 4 = Warning, 5 = Notice, 6 = Informational, 7 = Debug | integer |
| `syslog_rule_discard` | formData | true: the matching messages are discarded, false: they are kept | boolean |
| `syslog_rule_source` | formData | Sender IPv4/IPv6 address or network in CIDR notation (e.g. 10.0.0.0/24): only messages coming from it match the rule. Empty (default) matches any sender | string |
| `syslog_rule_pattern` | formData | RE2 regular expression the message must match. Empty (default) matches any message. Max 512 characters, no control characters | string |
| `syslog_rule_comment` | formData | Free-text description. Max 255 characters, no control characters | string |

**Responses**

`0` OK. The outcome of the operation is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise XL and administrators only); `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/edit/syslog/rule.lua

**Edit a syslog rule**

**Description:** Replaces all the fields of an existing syslog rule. Fails if the rule does not exist. Enterprise XL and administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `syslog_rule_id` | formData | Rule id (UUID, e.g. generated client side). For edit and delete it must identify an existing rule | string |
| `syslog_rule_enabled` | formData | 1 = rule enabled, 0 = disabled | integer |
| `syslog_rule_min_severity` | formData | Inclusive lower severity bound: 0 = Emergency, 1 = Alert, 2 = Critical, 3 = Error, 4 = Warning, 5 = Notice, 6 = Informational, 7 = Debug | integer |
| `syslog_rule_discard` | formData | true: the matching messages are discarded, false: they are kept | boolean |
| `syslog_rule_source` | formData | Sender IPv4/IPv6 address or network in CIDR notation (e.g. 10.0.0.0/24): only messages coming from it match the rule. Empty (default) matches any sender | string |
| `syslog_rule_pattern` | formData | RE2 regular expression the message must match. Empty (default) matches any message. Max 512 characters, no control characters | string |
| `syslog_rule_comment` | formData | Free-text description. Max 255 characters, no control characters | string |

**Responses**

`0` OK. The outcome of the operation is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise XL and administrators only); `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/delete/syslog/rule.lua

**Delete a syslog rule**

**Description:** Deletes a syslog rule. Fails if the rule does not exist. Enterprise XL and administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `syslog_rule_id` | formData | Rule id (UUID, e.g. generated client side). For edit and delete it must identify an existing rule | string |

**Responses**

`0` OK. The outcome of the operation is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise XL and administrators only); `-5` INVALID_ARGUMENTS

<a id="Wazuh"></a>

## Wazuh

### GET /lua/pro/rest/v2/get/wazuh/alerts.lua

**Get the Wazuh alerts**

**Description:** Page of the Wazuh alerts stored in ClickHouse, newest first by default. Only the alerts whose agent, source or destination IP is in the user allowed networks. Enterprise L, ClickHouse, Wazuh integration enabled, alerts capability (and historical flows capability for non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `start` | query | Row offset | integer |
| `length` | query | Page size (default 50, max 500) | integer |
| `sort` | query | Column to sort by (e.g. timestamp, rule_level, agent_name) | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text searched in description, agent, IPs, user name, domain and command | string |
| `epoch_begin` | query | Only alerts from this time (epoch) | integer |
| `epoch_end` | query | Only alerts up to this time (epoch) | integer |
| `min_level` | query | Only alerts with a rule level >= this | integer |

**Responses**

`0` OK. rsp: the alerts; recordsTotal/recordsFiltered: number of alerts matching the filters; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### GET /lua/pro/rest/v2/get/wazuh/alert.lua

**Get a Wazuh alert**

**Description:** All the fields of one Wazuh alert (NOT_FOUND outside the user allowed networks). Enterprise L, ClickHouse, Wazuh integration enabled, alerts capability (and historical flows capability for non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `wazuh_alert_id` | query | alert_id of the alert | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### GET /lua/pro/rest/v2/get/wazuh/alert_rules.lua

**Get the Wazuh alert rules**

**Description:** The rules choosing which Wazuh alerts are notified, by priority. Enterprise L, ClickHouse, Wazuh integration enabled, alerts capability (and historical flows capability for non-admin users).

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### POST /lua/pro/rest/v2/add/wazuh/alert_rule.lua

**Add a Wazuh alert rule**

**Description:** Adds a rule. Enterprise M, administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `wazuh_rule_id` | formData | Rule id (letters, digits and dashes) | string |
| `wazuh_rule_priority` | formData | Priority, lower first (default 100) | integer |
| `wazuh_rule_min_level` | formData | Minimum Wazuh rule level (0-15) of the alerts matched | integer |
| `wazuh_rule_groups` | formData | Comma separated Wazuh rule groups matched (empty: any) | string |
| `wazuh_rule_pattern` | formData | Lua pattern matched against the alert | string |
| `wazuh_rule_immediate` | formData | 1: notify immediately, 0: in the digest | integer |
| `wazuh_rule_subject` | formData | Subject of the notification | string |
| `wazuh_rule_enabled` | formData | 1: enabled (default), 0: disabled | integer |
| `wazuh_rule_comment` | formData | Free comment | string |

**Responses**

`0` OK. The outcome is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### POST /lua/pro/rest/v2/edit/wazuh/alert_rule.lua

**Edit a Wazuh alert rule**

**Description:** Changes a rule, and renames it when wazuh_rule_new_id is set. Enterprise M, administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `wazuh_rule_id` | formData | Id of the rule to change | string |
| `wazuh_rule_new_id` | formData | New id of the rule | string |
| `wazuh_rule_priority` | formData | Priority, lower first (default 100) | integer |
| `wazuh_rule_min_level` | formData | Minimum Wazuh rule level (0-15) of the alerts matched | integer |
| `wazuh_rule_groups` | formData | Comma separated Wazuh rule groups matched (empty: any) | string |
| `wazuh_rule_pattern` | formData | Lua pattern matched against the alert | string |
| `wazuh_rule_immediate` | formData | 1: notify immediately, 0: in the digest | integer |
| `wazuh_rule_subject` | formData | Subject of the notification | string |
| `wazuh_rule_enabled` | formData | 1: enabled (default), 0: disabled | integer |
| `wazuh_rule_comment` | formData | Free comment | string |

**Responses**

`0` OK. The outcome is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### POST /lua/pro/rest/v2/delete/wazuh/alert_rule.lua

**Delete a Wazuh alert rule**

**Description:** Enterprise M, administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `wazuh_rule_id` | formData | Id of the rule | string |

**Responses**

`0` OK. The outcome is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### GET /lua/pro/rest/v2/get/wazuh/alert_exceptions.lua

**Get the Wazuh alert exceptions**

**Description:** The Wazuh alerts matching an exception are not notified. Enterprise L, ClickHouse, Wazuh integration enabled, alerts capability (and historical flows capability for non-admin users).

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### POST /lua/pro/rest/v2/add/wazuh/alert_exception.lua

**Add a Wazuh alert exception**

**Description:** Adds an exception. Fails if the id is already used. Enterprise M, administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `wazuh_exception_id` | formData | Exception id (e.g. a UUID generated by the client) | string |
| `wazuh_exception_rule_id` | formData | Wazuh rule id (0: any) | integer |
| `wazuh_exception_agent_name` | formData | Agent name (empty: any) | string |
| `wazuh_exception_src_ip` | formData | Source IP (empty: any) | string |
| `wazuh_exception_dst_ip` | formData | Destination IP (empty: any) | string |
| `wazuh_exception_username` | formData | User name (empty: any) | string |
| `wazuh_exception_process` | formData | Process (empty: any) | string |
| `wazuh_exception_rule_group` | formData | Rule group (empty: any) | string |
| `wazuh_exception_pattern` | formData | Lua pattern matched against the alert | string |
| `wazuh_exception_enabled` | formData | 1: enabled (default), 0: disabled | integer |
| `wazuh_exception_comment` | formData | Free comment | string |

**Responses**

`0` OK. The outcome is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### POST /lua/pro/rest/v2/edit/wazuh/alert_exception.lua

**Edit a Wazuh alert exception**

**Description:** Changes an exception, and renames it when old_wazuh_exception_id differs from wazuh_exception_id. Enterprise M, administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `old_wazuh_exception_id` | formData | Current id of the exception (default: wazuh_exception_id) | string |
| `wazuh_exception_id` | formData | (New) id of the exception | string |
| `wazuh_exception_rule_id` | formData | Wazuh rule id (0: any) | integer |
| `wazuh_exception_agent_name` | formData | Agent name (empty: any) | string |
| `wazuh_exception_src_ip` | formData | Source IP (empty: any) | string |
| `wazuh_exception_dst_ip` | formData | Destination IP (empty: any) | string |
| `wazuh_exception_username` | formData | User name (empty: any) | string |
| `wazuh_exception_process` | formData | Process (empty: any) | string |
| `wazuh_exception_rule_group` | formData | Rule group (empty: any) | string |
| `wazuh_exception_pattern` | formData | Lua pattern matched against the alert | string |
| `wazuh_exception_enabled` | formData | 1: enabled (default), 0: disabled | integer |
| `wazuh_exception_comment` | formData | Free comment | string |

**Responses**

`0` OK. The outcome is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

### POST /lua/pro/rest/v2/delete/wazuh/alert_exception.lua

**Delete a Wazuh alert exception**

**Description:** Enterprise M, administrators only.

**Consumes:** `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `wazuh_exception_id` | formData | Id of the exception | string |

**Responses**

`0` OK. The outcome is in the 'result' field of the response: 'ok' on success, otherwise the error message; `-3` NOT_GRANTED (Enterprise M; writes: administrators only)

<a id="nAnalyst"></a>

## nAnalyst

### GET /lua/pro/rest/v2/get/llm/audit_log.lua

**Get the AI audit log**

**Description:** Actions done by the nAnalyst agent and by the users from the AI features, newest first (at most 500 rows). Enterprise, ClickHouse, nAnalyst license, administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch_begin` | query | Only actions from this time (epoch) | integer |
| `epoch_end` | query | Only actions up to this time (epoch) | integer |
| `username` | query | Only the actions of this user | string |
| `tool_name` | query | Only this tool (e.g. create_ai_policy) | string |
| `triggered_by` | query | llm (agent) or user (direct action) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/llm/token_usage.lua

**Get the LLM token usage**

**Description:** Calls, tokens and response times of the LLM calls in a time range: summary, by model, by call type, by user and timeline. Non administrators get only their own usage. Enterprise, ClickHouse, nAnalyst license.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `epoch_begin` | query | Range begin (epoch) | integer |
| `epoch_end` | query | Range end (epoch) | integer |
| `provider` | query | Only this provider (e.g. llm_openai) | string |
| `model` | query | Only this model | string |
| `username` | query | Only this user (administrators only) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/llm/model_prices.lua

**Get the LLM model prices**

**Description:** Price per million tokens (input and output, USD) of each model, used to compute the costs. Enterprise, ClickHouse, nAnalyst license, administrators only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/post/llm/upsert_model_price.lua

**Add or edit an LLM model price**

**Description:** Sets the price per million tokens of a model. Enterprise, ClickHouse, nAnalyst license, administrators only.

**Consumes:** `application/json`, `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `provider` | formData | Provider id (e.g. llm_openai) | string |
| `model` | formData | Model name | string |
| `input_price_usd` | formData | USD per million input tokens | number |
| `output_price_usd` | formData | USD per million output tokens | number |
| `edit` | formData | true to edit an existing price | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/post/llm/delete_model_price.lua

**Delete an LLM model price**

**Description:** Removes the price of a model. Enterprise, ClickHouse, nAnalyst license, administrators only.

**Consumes:** `application/json`, `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `provider` | formData | Provider id | string |
| `model` | formData | Model name | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/ai_policy/list.lua

**Get the AI policies**

**Description:** Policies: SQL queries on the historical data run at a fixed frequency, a non empty result raises an alert. With trigger and run counts. Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `periodicity` | query | Only this frequency: min, 5min, hourly, daily | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/post/ai_policy/upsert.lua

**Add an AI policy**

**Description:** Saves a new policy. Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Consumes:** `application/json`, `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ai_policy_name` | formData | Policy name | string |
| `sql_query` | formData | ClickHouse query: a non empty result is a violation | string |
| `periodicity` | formData | min, 5min, hourly or daily | string |
| `policy_description` | formData | Description | string |
| `alert_description` | formData | Message shown in the alert | string |
| `custom_score` | formData | Alert score (1, 10, 50, 100, 150, 200, 250) | integer |
| `explanation` | formData | How the query works | string |
| `message_template` | formData | Alert message template | string |
| `message_variables` | formData | JSON array of the template variables | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-6` MISSING_PARAMETERS; `-4` BAD_FORMAT

### POST /lua/pro/rest/v2/post/ai_policy/update.lua

**Edit an AI policy**

**Description:** Changes an existing policy (same fields of the add, plus its id). Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Consumes:** `application/json`, `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `policy_id` | formData | Policy id | integer |
| `ai_policy_name` | formData | Policy name | string |
| `sql_query` | formData | ClickHouse query | string |
| `periodicity` | formData | min, 5min, hourly or daily | string |
| `policy_description` | formData | Description | string |
| `alert_description` | formData | Message shown in the alert | string |
| `custom_score` | formData | Alert score | integer |
| `explanation` | formData | How the query works | string |
| `message_template` | formData | Alert message template | string |
| `message_variables` | formData | JSON array of the template variables (omitted: kept) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-6` MISSING_PARAMETERS; `-1` NOT_FOUND

### POST /lua/pro/rest/v2/delete/ai_policy/delete.lua

**Delete an AI policy**

**Description:** Removes a policy. Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Consumes:** `application/json`, `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `policy_id` | formData | Policy id | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-6` MISSING_PARAMETERS

### GET /lua/pro/rest/v2/get/analyst_pipeline/list.lua

**Get the analyst playbooks**

**Description:** Saved playbooks (multi step investigations, SQL queries on the historical data) with name, description, provider and date. Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/analyst_pipeline/get.lua

**Get an analyst playbook**

**Description:** One playbook with its definition (params, stages and their SQL templates). Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pipeline_id` | query | Playbook id (UUID) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-6` MISSING_PARAMETERS; `-1` NOT_FOUND

### POST /lua/pro/rest/v2/delete/analyst_pipeline/delete.lua

**Delete an analyst playbook**

**Description:** Removes a playbook. Enterprise XL, ClickHouse, nAnalyst license, administrators only.

**Consumes:** `application/json`, `application/x-www-form-urlencoded`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pipeline_id` | formData | Playbook id (UUID) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-6` MISSING_PARAMETERS

<a id="Traffic Model"></a>

## Traffic Model

### GET /lua/pro/rest/v2/get/traffic_model/server_types.lua

**Get the server types**

**Description:** Server types of the traffic model (DNS, NTP, ...): id, label, application protocols. Enterprise XL, ClickHouse.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/traffic_model/servers.lua

**Get the servers of a day range**

**Description:** Servers of a type seen in a day range, from the daily model built on the historical flows, one page per request. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `server_type` | query | Server type id (see server_types) | integer |
| `day` | query | First day (YYYY-MM-DD) | string |
| `day_to` | query | Last day (YYYY-MM-DD), default: day | string |
| `start` | query | Row offset | integer |
| `length` | query | Page size (default 10, max 500) | integer |
| `sort` | query | Column to sort by | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text searched in the server address | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (also when the query fails)

### GET /lua/pro/rest/v2/get/traffic_model/expected.lua

**Get the servers against the expected ones**

**Description:** Servers seen in a day range against the expected ones of the Network Configuration: EXPECTED, UNEXPECTED, MISSING, with a summary. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `server_type` | query | Server type id | integer |
| `day` | query | First day (YYYY-MM-DD) | string |
| `day_to` | query | Last day (YYYY-MM-DD) | string |
| `section` | query | seen (servers seen) or configured (expected ones) | string |
| `status` | query | Only this status | string |
| `start` | query | Row offset | integer |
| `length` | query | Page size (default 10, max 500) | integer |
| `sort` | query | Column to sort by | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text searched in the server address | string |
| `l7_proto` | query | Only the servers that received traffic of this nDPI protocol id | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (also when the query fails)

### GET /lua/pro/rest/v2/get/traffic_model/daily_report.lua

**Preview the daily report email**

**Description:** Builds the daily report of the interface (servers of a day against the previous day: new, gone, expected not seen, configured) as the email would be, without sending it. The answer is empty when there is nothing to report. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `day` | query | Day of the report (YYYY-MM-DD), default yesterday | string |

**Responses**

`0` OK: title, message, link and the email html; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INVALID_INTERFACE

### POST /lua/pro/rest/v2/delete/traffic_model/day.lua

**Delete the model of a date range**

**Description:** Removes all the traffic model and server model rows of the date range (all the interfaces) and all the expected servers of the Network Configuration. Admin, Enterprise XL, ClickHouse, checks capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `day_from` | formData | First day (YYYY-MM-DD) | string |
| `day_to` | formData | Last day (YYYY-MM-DD) | string |

**Responses**

`0` OK: days deleted; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (also when the delete fails)

### GET /lua/pro/rest/v2/get/traffic_model/compare.lua

**Compare the servers of two days**

**Description:** Servers of a day against an earlier one: NEW (newly seen), GONE (no longer seen), UP, DOWN, SAME, with a summary, seen_old and seen_new (servers seen on each day: seen_old + NEW - GONE = seen_new) and the days without data. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `server_type` | query | Server type id | integer |
| `day_old` | query | Reference day (YYYY-MM-DD) | string |
| `day_new` | query | Day to check (YYYY-MM-DD) | string |
| `status` | query | CHANGES (default, all but SAME), ALL, NEW, GONE, UP, DOWN, SAME | string |
| `start` | query | Row offset | integer |
| `length` | query | Page size (default 10, max 500) | integer |
| `sort` | query | Column to sort by | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text searched in the server address | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (also when the query fails)

### GET /lua/pro/rest/v2/get/traffic_model/graph.lua

**Get the traffic model graph of a day or of a host**

**Description:** Busiest client to server communications of the interface in a day (IPv4 and IPv6), with the hosts as nodes. Servers carry server_type and role server. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `day` | query | Day (YYYY-MM-DD) | string |
| `max_edges` | query | Max communications returned (default and max 2000) | integer |
| `host` | query | Return only the communications of this host (IPv4 or IPv6) | string |
| `host_role` | query | With host: client (the host is the source, default is server) or server (the host is the destination) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/traffic_model/clients.lua

**Get the clients of the servers of a type**

**Description:** Clients that used the servers of a type in a day range, from the daily model built on the historical flows: servers contacted (count and the busiest ones with their protocols), flows and bytes, one page per request. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `server_type` | query | Server type id (see server_types) | integer |
| `day` | query | First day (YYYY-MM-DD) | string |
| `day_to` | query | Last day (YYYY-MM-DD), default is day | string |
| `start` | query | First row of the page | integer |
| `length` | query | Rows of the page (max 500) | integer |
| `sort` | query | ip, name, servers, days_seen, flows or bytes (default servers) | string |
| `order` | query | asc or desc (default) | string |
| `map_search` | query | Address or host name to search | string |
| `server` | query | Only the clients of this server address | string |
| `l7_proto` | query | Only the traffic of this nDPI protocol id | integer |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/traffic_model/client_servers.lua

**Get the servers of a type contacted by a client**

**Description:** Servers of a type contacted by one client in a day range, from the daily model built on the historical flows: protocols, flows and bytes, one page per request. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `server_type` | query | Server type id (see server_types) | integer |
| `client` | query | Client address (IPv4 or IPv6) | string |
| `day` | query | First day (YYYY-MM-DD) | string |
| `day_to` | query | Last day (YYYY-MM-DD), default is day | string |
| `start` | query | First row of the page | integer |
| `length` | query | Rows of the page (max 500) | integer |
| `sort` | query | ip, name, days_seen, flows or bytes (default flows) | string |
| `order` | query | asc or desc (default) | string |
| `map_search` | query | Server address or host name to search | string |
| `l7_proto` | query | Only the traffic of this nDPI protocol id | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-2` INVALID_INTERFACE or NOT_ENABLED (the traffic model has not been built yet)

### GET /lua/pro/rest/v2/get/traffic_model/overview.lua

**Get the servers of all the server types of an interface on a day against another day**

**Description:** One row per server type with the numbers of the Servers page on day_new: configured (set in the Network Configuration page), configured_seen, configured_not_seen, not_configured_seen and total (configured_seen + configured_not_seen + not_configured_seen). Seen: the server answered flows that day. old has the same numbers on day_old. The daily report email has the same table. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface id | integer |
| `day_old` | query | Day to compare with (YYYY-MM-DD) | string |
| `day_new` | query | Day (YYYY-MM-DD) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/traffic_model/protocols.lua

**Get the protocols of the traffic towards the servers of a type**

**Description:** Protocols (nDPI id and name) of the traffic towards the servers of a type in a day range, the busiest first: the values of the protocol filter. Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `server_type` | query | Server type id (see server_types) | integer |
| `day` | query | First day (YYYY-MM-DD) | string |
| `day_to` | query | Last day (YYYY-MM-DD), default is day | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/traffic_model/calendar.lua

**Get the days with server changes**

**Description:** For each day of a range: nodata, baseline, same or changed (servers appeared and disappeared). Enterprise XL, ClickHouse, checks capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `server_type` | query | Server type id | integer |
| `day_from` | query | First day (YYYY-MM-DD) | string |
| `day_to` | query | Last day (YYYY-MM-DD) | string |

**Responses**

`0` OK; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/delete/traffic_model/servers.lua

**Remove servers from the server model**

**Description:** Removes misclassified servers of a type from the server model of a day range: the given hosts, or all the servers of the type with all (the traffic model is kept). Enterprise XL, ClickHouse, checks capability, administrator.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK: { removed: number of valid addresses }; `-2` NOT_ENABLED (the traffic model has not been built yet); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (also when the delete fails)

<a id="Traffic Rules"></a>

## Traffic Rules

### POST /lua/pro/rest/v2/add/interface/traffic_rules/rule.lua

**Add or edit a traffic rule**

**Description:** Adds a traffic rule (an alert when a timeseries goes above or below a threshold), or edits the one with row_id. Answers the saved rule. Enterprise M and administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface identifier | integer |
| `rule_type` | formData | Type of the monitored element | string |
| `rule_target` | formData | Monitored element: interface id, host IP (optionally @VLAN, * = all the local hosts), host pool id, network, VLAN id, traffic profile, ASN or flow exporter IP (* = all the exporters) | string |
| `target_label` | formData | Label of the target (host pool, VLAN) | string |
| `metric` | formData | Timeseries schema measured (e.g. iface:traffic, host:traffic-RX) | string |
| `extra_metric` | formData | Application or category of the per application/category metrics (e.g. protocol:HTTP, category:Web) | string |
| `metric_label` | formData | Label of the metric shown in the rules list | string |
| `metric_type` | formData | How the metric is measured | string |
| `threshold` | formData | Threshold (>= 0): bytes (volume), bits per second (throughput), percent or plain value | number |
| `threshold_sign` | formData | 1: alert when above the threshold, -1: when below | integer |
| `frequency` | formData | How often the rule is checked (the period just ended is measured) | string |
| `severity_id` | formData | Severity of the alerts raised by the rule (the ones selectable in the Behavioural Checks): 2 = Info, 3 = Notice, 4 = Warning, 5 = Error, 6 = Critical, 8 = Emergency | integer |
| `row_id` | formData | Id of the rule to edit (empty: a new rule is added) | string |
| `network_id` | formData | Network id (CIDR rules) | string |
| `port` | formData | Flow exporter interface index, * = all the interfaces (exporter rules) | string |
| `device_ifid` | formData | Interface where the flow exporter is seen (exporter rules) | integer |

**Responses**

`0` OK. The saved rule (with its row_id); `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS. The 'error' field says why: invalid_rule_type, invalid_target, invalid_metric, invalid_frequency, invalid_metric_type, invalid_threshold, invalid_severity, duplicate_rule; `-1` NOT_FOUND (row_id of a rule that does not exist); `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/interface/traffic_rules/data.lua

**Get the traffic rules**

**Description:** Traffic rules of an interface. Each rule: row_id, rule_type, target, metric, extra_metric, metric_label, metric_type, threshold, threshold_sign, frequency, severity_id (missing = 5, Error), the per type fields (selected_iface, host_pool_label, vlan_label, network_id, name, flow_exp_ifid, ifid) and last_measurement (the last measured value, missing for the rules on all the hosts or exporters). Enterprise M and administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK. Array of rules; `-3` NOT_GRANTED (administrators only); `-2` INVALID_INTERFACE

<a id="Syslog"></a>

## Syslog

### GET /lua/pro/rest/v2/get/syslog/stats.lua

**Get the syslog message counters**

**Description:** Counters since ntopng started, summed over the syslog interfaces: messages received by the collector and messages stored in ClickHouse. The history is the iface:syslog_messages timeseries. Enterprise XL, administrators only.

**Produces:** `application/json`

**Responses**

`0` OK. rsp: { received, stored, ifids: [interfaces with the counters] }; `-3` NOT_GRANTED (Enterprise XL, administrators only)

<a id="Notification Recipients"></a>

## Notification Recipients

### POST /lua/rest/v2/add/notification/recipient.lua

**Add a notification recipient**

**Description:** Add a notification recipient on an existing connection (endpoint_id) or on a new connection created in the same call (endpoint_conf_type and its params). Plus the params of the channel type (e.g. email: smtp_server, email_sender, email_recipient; slack: slack_sender_username, slack_webhook), as listed by the notification page context. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `recipient_name` | formData | Recipient name (unique) | string |
| `endpoint_id` | formData | Existing connection id (omit to create a new connection) | integer |
| `endpoint_conf_type` | formData | Channel type of the new connection (email, slack, telegram, webhook...) | string |
| `endpoint_conf_name` | formData | Name of the new connection (default: the recipient name) | string |
| `recipient_policies` | formData | Comma separated ids of the notification policies delivering to the recipient (e.g. 0,2) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### POST /lua/rest/v2/delete/notification/endpoint.lua

**Delete a notification connection**

**Description:** Delete a notification connection and all the recipients using it. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `endpoint_id` | formData | Connection id | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### POST /lua/rest/v2/delete/notification/recipient.lua

**Delete a notification recipient**

**Description:** Delete a notification recipient (not the builtin one). Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `recipient_id` | formData | Recipient id | integer |
| `delete_endpoint` | formData | true: also delete its connection when no other recipient uses it | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### POST /lua/rest/v2/edit/notification/endpoint.lua

**Edit a notification connection**

**Description:** Edit name and params of a notification connection: all the params are replaced, missing optional ones are cleared. Plus the params of the channel type (e.g. email: smtp_server, email_sender, email_recipient; slack: slack_sender_username, slack_webhook), as listed by the notification page context. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `endpoint_id` | formData | Connection id | integer |
| `endpoint_conf_name` | formData | Connection name | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### POST /lua/rest/v2/edit/notification/recipient.lua

**Edit a notification recipient**

**Description:** Edit name and recipient params of a notification recipient (the notifications it receives are selected by the notification policies). The builtin alert database recipient keeps its name. Plus the params of the channel type (e.g. email: smtp_server, email_sender, email_recipient; slack: slack_sender_username, slack_webhook), as listed by the notification page context. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `recipient_id` | formData | Recipient id | integer |
| `recipient_name` | formData | Recipient name | string |
| `recipient_minimum_severity` | formData | Builtin alert database recipient only: minimum severity id of the stored alerts (default: notice) | integer |
| `recipient_policies` | formData | Comma separated ids of the notification policies delivering to the recipient, empty for none (not sent: unchanged; ignored for the builtin recipient) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### POST /lua/rest/v2/exec/notification/test_recipient.lua

**Test a notification recipient**

**Description:** Send a test message with an existing connection (endpoint_id) or a not yet saved one (endpoint_conf_type and its params), plus the recipient params. Nothing is saved. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `endpoint_id` | formData | Existing connection id | integer |
| `endpoint_conf_type` | formData | Channel type of a not yet saved connection | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### GET /lua/rest/v2/get/notification/endpoints.lua

**List notification connections**

**Description:** Notification connections (endpoints: SMTP server, bot token, webhook URL...) with their params, credentials included, and the number of recipients using them. Builtin connections are excluded. Admin only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### GET /lua/rest/v2/get/notification/recipients.lua

**List notification recipients**

**Description:** Notification recipients (builtin alert database recipient included) with channel type, connection, recipient params, the notification policies delivering to them and delivery stats (minimum_severity: builtin recipient only). Admin only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. endpoint_recipient_already_existing, missing_mandatory_param, invalid_param)

### POST /lua/rest/v2/delete/recipients.lua

**Delete all defined recipients and reset them to factory-defaults**

**Description:** Delete all defined recipients and reset them to factory-defaults

**Produces:** `application/json`

**Responses**

`0` OK

<a id="Notification Policies"></a>

## Notification Policies

### POST /lua/rest/v2/exec/notification/simulate.lua

**Simulate the notifications of an alert**

**Description:** What happens when the alerts of a check, traffic rule, SNMP device rule, active monitoring measurement, AI policy or Wazuh alert rule are raised, with the given (not necessarily saved) values of its dialog: per alert, whether it is stored and the notified recipients (status match or conditional) with the notification policies notifying them and their conditions (e.g. the host pools when the host is not known). Nothing is sent. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `simulation_source` | formData | What raises the alerts | string |
| `check_subdir` | formData | check: check family (e.g. host, flow) | string |
| `script_key` | formData | check: check key | string |
| `JSON` | formData | check: hooks configuration of the dialog (as set/checks/check_config.lua), the saved one when missing | string |
| `tag_ids` | formData | check, am: comma separated tag ids of the dialog, the saved ones when missing | string |
| `ifid` | formData | traffic_rule, snmp_rule: interface id (host pools of the hosts) | integer |
| `rule_type` | formData | traffic_rule: rule type (Host, interface, CIDR, host_pool, vlan, profiles, asn, exporter) | string |
| `rule_target` | formData | traffic_rule: rule target (* for any host) | string |
| `snmp_device` | formData | snmp_rule: SNMP device IP, or all | string |
| `am_host` | formData | am: measured host | string |
| `measurement` | formData | am: measurement (e.g. icmp) | string |
| `custom_score` | formData | ai_policy: alert score | integer |
| `wazuh_rule_immediate` | formData | wazuh_rule: 1 sent immediately, 0 batched digest | string |

**Responses**

`0` OK (rsp: list of alerts {title, severity, category, disabled, stored, stored_condition, stored_reason, feeds_issues, recipients [{recipient_id, name, destination, status, policies [{policy_id, name, conditions}]}]}); `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (unknown source, check or rule type)

### GET /lua/rest/v2/get/notification/policies.lua

**List notification policies**

**Description:** Notification policies: condition (type, minimum severity, categories, host pools, active monitoring hosts, tags) and recipients, delivered once per recipient also when more policies match. Admin only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. policy_already_existing, policy_not_existing, too_many_policies, invalid_notifications_type, endpoint_recipient_not_existing, recipient_alerts_only)

### POST /lua/rest/v2/add/notification/policy.lua

**Add a notification policy**

**Description:** Add a notification policy: the notifications matching its condition are delivered to its recipients. An empty filter list is no filter. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `policy_name` | formData | Policy name (unique) | string |
| `policy_enabled` | formData | false: the policy delivers nothing (default: true) | boolean |
| `policy_notifications_type` | formData | What the policy delivers: alerts, reports, active_scans, wazuh_alerts (Enterprise M+), issues (Enterprise XXL+ with the issues enabled) | string |
| `policy_minimum_severity` | formData | Minimum severity id (default: notice) | integer |
| `policy_check_categories` | formData | Comma-separated alert category ids (empty: all) | string |
| `policy_host_pools` | formData | Comma-separated host pool ids (empty: all) | string |
| `policy_am_hosts` | formData | Comma-separated active monitoring host keys (empty: all) | string |
| `policy_labels` | formData | Comma-separated tag ids, at least one on the alert (empty: all) | string |
| `policy_recipients` | formData | Comma-separated recipient ids (builtin recipient excluded) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. policy_already_existing, policy_not_existing, too_many_policies, invalid_notifications_type, endpoint_recipient_not_existing, recipient_alerts_only)

### POST /lua/rest/v2/edit/notification/policy.lua

**Edit a notification policy**

**Description:** Edit a notification policy (all its params are replaced). Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `policy_id` | formData | Policy id | integer |
| `policy_name` | formData | Policy name (unique) | string |
| `policy_enabled` | formData | false: the policy delivers nothing (default: true) | boolean |
| `policy_notifications_type` | formData | What the policy delivers: alerts, reports, active_scans, wazuh_alerts (Enterprise M+), issues (Enterprise XXL+ with the issues enabled) | string |
| `policy_minimum_severity` | formData | Minimum severity id (default: notice) | integer |
| `policy_check_categories` | formData | Comma-separated alert category ids (empty: all) | string |
| `policy_host_pools` | formData | Comma-separated host pool ids (empty: all) | string |
| `policy_am_hosts` | formData | Comma-separated active monitoring host keys (empty: all) | string |
| `policy_labels` | formData | Comma-separated tag ids, at least one on the alert (empty: all) | string |
| `policy_recipients` | formData | Comma-separated recipient ids (builtin recipient excluded) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. policy_already_existing, policy_not_existing, too_many_policies, invalid_notifications_type, endpoint_recipient_not_existing, recipient_alerts_only)

### POST /lua/rest/v2/delete/notification/policy.lua

**Delete a notification policy**

**Description:** Delete a notification policy (its recipients are not deleted). Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `policy_id` | formData | Policy id | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (rsp.type: error type, e.g. policy_already_existing, policy_not_existing, too_many_policies, invalid_notifications_type, endpoint_recipient_not_existing, recipient_alerts_only)

<a id="Active Monitoring"></a>

## Active Monitoring

### POST /lua/rest/v2/set/active_monitoring/measurement.lua

**Add or edit an Active Monitoring measurement**

**Description:** Adds (action=add) or changes (action=edit, identified by old_host and old_measurement) a measurement. POST (form data, CSRF checked). Requires the Active Monitoring capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `action` | formData | add or edit | string |
| `am_host` | formData | Host or URL to measure | string |
| `measurement` | formData | Measurement type (e.g. icmp, cicmp, http, https, throughput, speedtest) | string |
| `ifname` | formData | Interface used for the measurement | string |
| `threshold` | formData | Alert threshold (unit of the measurement) | string |
| `granularity` | formData | How often to measure (e.g. min, 5mins, hour) | string |
| `tag_ids` | formData | Comma separated ids of the tags added to the alerts of the measurement, empty for none. Not sent: an edit keeps the current tags | string |
| `old_host` | formData | With action=edit: the current host | string |
| `old_measurement` | formData | With action=edit: the current measurement | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/export/active_monitoring/config.lua

**Export the active monitoring configuration as a JSON file**

**Description:** Export the active monitoring configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/import/active_monitoring/config.lua

**Import the active monitoring configuration providing a JSON file**

**Description:** Import the active monitoring configuration

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### GET /lua/rest/v2/reset/active_monitoring/config.lua

**Reset Active Monitoring configuration**

**Description:** Reset active monitoring configuration

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/active_monitoring/list.lua

**List the active monitoring measurements**

**Description:** Measurements with their last result and thresholds. Requires access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | string |
| `measurement` | query | Only this measurement type (e.g. icmp, http) | string |
| `only_alerted_hosts` | query | Only the measurements with engaged alerts | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/active_monitoring/filters.lua

**Active monitoring table filters**

**Description:** Filters (measurement types) of the active monitoring table. Requires access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/active_monitoring/measurements.lua

**Active monitoring measurement types**

**Description:** Definitions of the available measurements (units, thresholds, granularities). Requires access to the system interface.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/active_monitoring/timeseries_list.lua

**Active monitoring hosts with timeseries**

**Description:** Active monitoring hosts, the sources of the timeseries charts. Requires access to the system interface.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/delete/active_monitoring/measurement.lua

**Delete an active monitoring measurement**

**Description:** Removes a measurement. Requires the active monitoring capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `am_host` | formData | Monitored host | string |
| `measurement` | formData | Measurement type (e.g. icmp, http) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

<a id="SNMP"></a>

## SNMP

### POST /lua/pro/rest/v2/set/snmp/auto_assign_role.lua

**Set the role of the SNMP interfaces by name**

**Description:** Gives a role to every interface whose name contains the filter, on all the SNMP devices; returns how many were changed. POST with a JSON body (CSRF checked), never from the query string. Requires the SNMP capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `payload` | body | JSON body: { "interface_name_filter": "eth", "role": "uplink", "csrf": "..." } | object |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-59` MISSING_PARAMETERS

### GET /lua/pro/rest/v2/get/snmp/device/similarity.lua

**Get the SNMP devices similar to a device**

**Description:** Devices with a similar traffic behaviour. Enterprise.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-1` NOT_FOUND (not available)

### GET /lua/pro/rest/v2/get/snmp/topology_map.lua

**Get the SNMP topology map**

**Description:** Nodes and links of the network topology learned from the SNMP devices; with host only the part around that device. Enterprise.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of an SNMP device (optional) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-1` NOT_FOUND (not available)

### GET /lua/pro/rest/v2/get/snmp/device/topology.lua

**Get the neighbours of an SNMP device**

**Description:** The devices connected to an SNMP device (LLDP/CDP and bridge tables). Enterprise.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-1` NOT_FOUND (not available)

### POST /lua/pro/rest/v2/add/snmp/import_devices.lua

**Import SNMP devices**

**Description:** Adds the devices of a configuration export (devices, JSON as produced by export/snmp/config.lua) or of a CSV (devices_csv, one device per line: ip, read_community, write_community, version, level, username, auth_protocol, auth_passphrase, privacy_protocol, privacy_passphrase, context). POST (form data, CSRF checked). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `devices` | formData | JSON configuration to import | string |
| `devices_csv` | formData | CSV of the devices to import | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-8` BAD_CONTENT

### POST /lua/pro/rest/v2/check/snmp/ping_all_devices.lua

**Poll all the SNMP devices now**

**Description:** Starts a poll of every SNMP device without waiting for the next periodic one. Administrators only, Enterprise M.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/delete/snmp/unresponsive_devices.lua

**Delete the unresponsive SNMP devices**

**Description:** Deletes the devices that do not answer to SNMP. POST only (CSRF checked). Administrators only, Enterprise M.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (not a POST)

### POST /lua/pro/rest/v2/delete/snmp/all_devices.lua

**Delete all the SNMP devices**

**Description:** Deletes every configured SNMP device. POST only (CSRF checked). Administrators only.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (not a POST)

### POST /lua/pro/rest/v2/edit/snmp/device/config.lua

**Edit the polling options of an SNMP device**

**Description:** Sets the options of a device. POST (form data, CSRF checked). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | IP address of the SNMP device | string |
| `toggle_snmp_qos_mib_polling` | formData | 1 to poll the Cisco QoS MIB, 0 not to | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-1` NOT_FOUND (not an administrator)

### GET /lua/pro/rest/v2/get/snmp/device/config.lua

**Get the polling options of an SNMP device**

**Description:** Options of a device: { toggle_snmp_qos_mib_polling }. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-1` NOT_FOUND (not an administrator)

### GET /lua/pro/rest/v2/get/snmp/device/available_interfaces.lua

**List the interfaces of an SNMP device**

**Description:** The interfaces of a device ([{ id, name }]), from the SNMP cache. Requires the SNMP capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/list.lua

**List the SNMP devices**

**Description:** The configured SNMP devices with their polling status (name, description, version, last poll, interfaces with errors, unreachable). Requires the SNMP capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `device_responsiveness` | query | Only the 'responsive' or the 'unresponsive' devices | string |
| `verbose` | query | More details per device | boolean |
| `rsp_format` | query | Response in the table format | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/add/snmp/device.lua

**Add SNMP devices**

**Description:** Add devices to the monitored SNMP devices. POST (form data, CSRF checked). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `snmp_host` | formData | IP address or symbolic name of and an SNMP device | string |
| `snmp_read_community` | formData | The SNMP read community to use (SNMP v1/v2c only) | string |
| `snmp_write_community` | formData | The SNMP write community to use (SNMP v1/v2c only) | string |
| `snmp_version` | formData | The SNMP version to use: 2 (SNMP v3), 1 (v2c) or 0 (v1) | string |
| `snmp_level` | formData | Used only with SNMP v3: noAuthNoPriv, authNoPriv, or authPriv) | string |
| `snmp_auth_protocol` | formData | Used only with SNMP v3 and level not set to noAuthNoPriv: MD5 or SHA | string |
| `snmp_auth_passphrase` | formData | Used only with SNMP v3 and level not set to noAuthNoPriv: 8 chars+ passphrase | string |
| `snmp_privacy_protocol` | formData | Used only with SNMP v3 and level set to autPriv: DES or AES | string |
| `snmp_privacy_passphrase` | formData | Used only with SNMP v3 and level set to autPriv: 8 chars+ passphrase | string |
| `cidr` | formData | Either 24 or 32. If 32, snmp_host is treated as single host. If 24 snmp_host is treated as as CIDR address | string |
| `snmp_username` | formData | SNMP v3 username | string |
| `snmp_context` | formData | SNMP v3 context name | string |

**Responses**

`-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-9` NAME_RESOLUTION_FAILED; `-10` SNMP_DEVICE_ALREADY_ADDED; `-11` SNMP_DEVICE_UNREACHABLE; `-12` NO_SNMP_DEVICE_DISCOVERED

### POST /lua/pro/rest/v2/change/snmp/device/interface/status.lua

**Change SNMP device interface status**

**Description:** Change the status of an SNMP device in terface to up or down

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | IP address of an SNMP device | string |
| `snmp_admin_status` | formData | The new admin status, either 'up' or 'down' | string |
| `snmp_port_idx` | formData | The index of the SNMP device interface | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-26` SNMP_DEVICE_INTERFACE_STATUS_CHANGE_FAILED

### POST /lua/pro/rest/v2/delete/snmp/device.lua

**Delete an SNMP device**

**Description:** Delete an SNMP device from the monitored SNMP devices. POST (form data, CSRF checked). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | IP address of an SNMP device | string |

**Responses**

`0` SNMP_DEVICE_DELETED_SUCCESSFULLY; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/edit/snmp/device/device.lua

**Edit a SNMP device**

**Description:** Edit an existing monitored SNMP device. POST (form data, CSRF checked).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `snmp_host` | formData | IP address or symbolic name of and an SNMP device | string |
| `snmp_read_community` | formData | The SNMP read community to use (SNMP v1/v2c only). Empty keeps the saved one | string |
| `snmp_write_community` | formData | The SNMP write community to use (SNMP v1/v2c only). Empty keeps the saved one | string |
| `snmp_remove_write_community` | formData | true removes the saved write community (an empty snmp_write_community keeps it) | boolean |
| `snmp_version` | formData | The SNMP version to use: 2 (SNMP v3), 1 (v2c) or 0 (v1) | string |
| `snmp_level` | formData | Used only with SNMP v3: noAuthNoPriv, authNoPriv, or authPriv) | string |
| `snmp_auth_protocol` | formData | Used only with SNMP v3 and level not set to noAuthNoPriv: MD5 or SHA | string |
| `snmp_auth_passphrase` | formData | Used only with SNMP v3 and level not set to noAuthNoPriv: 8 chars+ passphrase. Empty keeps the saved one | string |
| `snmp_privacy_protocol` | formData | Used only with SNMP v3 and level set to autPriv: DES or AES | string |
| `snmp_privacy_passphrase` | formData | Used only with SNMP v3 and level set to authPriv: 8 chars+ passphrase. Empty keeps the saved one | string |
| `snmp_username` | formData | SNMP v3 username | string |
| `snmp_context` | formData | SNMP v3 context name | string |

**Responses**

`-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-9` NAME_RESOLUTION_FAILED; `-10` SNMP_DEVICE_ALREADY_ADDED; `-11` SNMP_DEVICE_UNREACHABLE; `-12` NO_SNMP_DEVICE_DISCOVERED; `-22` SNMP_UNKNOWN_DEVICE

### GET /lua/pro/rest/v2/get/snmp/device/bridge.lua

**Get bridge MIB information**

**Description:** Get bridge MIB information for a single or all SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | The IP address of the SNMP device (optional, all devices are returned if empty) | string |

**Responses**

`-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/interfaces.lua

**Get interfaces information**

**Description:** Get interfaces information for a single or all SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | The IP address of the SNMP device (optional, all devices are returned if empty) | string |

**Responses**

`-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/lldp.lua

**Get LLDP adjacency information**

**Description:** Get LLDP adjacencies for a single or all SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | The IP address of the SNMP device (optional, all devices are returned if empty) | string |

**Responses**

`-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/list.lua

**Get all SNMP devices**

**Description:** Retrieve all configured SNMP devices.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/system.lua

**Get system information**

**Description:** Get system information (SNMPv2-MIB system group) for a single or all SNMP devices; oid_label is the object id with the hardware model when known. Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | The IP address of the SNMP device (optional, all devices are returned if empty) | string |

**Responses**

`-3` NOT_GRANTED; `0` OK

### GET /lua/rest/v2/reset/snmp/config.lua

**Reset SNMP configuration**

**Description:** Reset SNMP configuration including all configured devices

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/page_context.lua

**Context of the SNMP devices page**

**Description:** Number and limit of the configured devices, LLDP/CDP availability, polling/timeseries/license flags and the default community used by the SNMP devices page. Administrators only. Requires access to the system interface.

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/device/page_context.lua

**Context of the SNMP device page**

**Description:** Device name and the data it exposes (interfaces, LLDP/CDP, BRIDGE, NET-SNMP, Printer MIBs, QoS polling, flow export); found is false for a device not configured. Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/device/netsnmp.lua

**NET-SNMP resources of an SNMP device**

**Description:** CPU states (%), memory and swap (bytes) from the UCD-SNMP-MIB and which of their timeseries exist (charts). Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/device/printer.lua

**Printer data of an SNMP device**

**Description:** Printer-MIB data; error_state_bytes are the bytes of hrPrinterDetectedErrorState (flag bits, RFC 1759). Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/mac/macs_info.lua

**MAC addresses learned by an SNMP device**

**Description:** MAC addresses of the BRIDGE-MIB forwarding table, of all the ports or of one, with manufacturer, device type id (discover id, e.g. printer) and associated IP. Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |
| `snmp_port_idx` | query | Only the MACs of this port (SNMP ifIndex) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/interface/page_context.lua

**Context of the SNMP interface page**

**Description:** Device and interface names, role label, learned MACs, timeseries and the interface exporting the flows of this port (exporter_ifid); found is false for an unknown device or interface. Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |
| `snmp_port_idx` | query | SNMP ifIndex of the interface | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/interface/details.lua

**Details of an SNMP interface**

**Description:** Raw interface data: name, type, IPs, VLAN, speeds (bit/s), status codes, counters, last change (s), LLDP neighbour, last usage (%, -1 when not available). Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |
| `snmp_port_idx` | query | SNMP ifIndex of the interface | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/interface/config.lua

**Configuration of an SNMP interface**

**Description:** Alerts toggles, role, usage page exclusion, speeds (bit/s) and admin status of an interface. Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |
| `snmp_port_idx` | query | SNMP ifIndex of the interface | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/edit/snmp/interface/config.lua

**Edit the configuration of an SNMP interface**

**Description:** Only the parameters sent are changed. toggle_snmp_port_admin_status sets the admin status on the device (SNMP SET, admin_status_set_failed when it fails). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | IP address of the SNMP device | string |
| `snmp_port_idx` | formData | SNMP ifIndex of the interface | integer |
| `toggle_snmp_alerts_port_status_change` | formData | Alerts on operational status changes | boolean |
| `toggle_snmp_alerts_port_duplexstatus_change` | formData | Alerts on duplex status changes | boolean |
| `toggle_snmp_alerts_port_errors` | formData | Alerts on discards/errors | boolean |
| `toggle_exclude_from_usage_page` | formData | Exclude the interface from the usage page | boolean |
| `snmp_interface_role_change` | formData | Interface role (a value of get/snmp/interface_roles_options.lua) | string |
| `uplink_speed` | formData | Uplink speed in Gbit (>= 0) | number |
| `downlink_speed` | formData | Downlink speed in Gbit (>= 0) | number |
| `toggle_snmp_port_admin_status` | formData | Admin status up (true) or down (false) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/device/rules.lua

**List the SNMP interface rules**

**Description:** Threshold rules on the metrics of SNMP interfaces. Enterprise, requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | string |

**Responses**

`0` OK: rsp = [{ id, device { id, label }, interface { id, label }, metric { id, label, type }, frequency, threshold { value, sign, label, unit } }]; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/add/snmp/device/rule.lua

**Add or edit an SNMP interface rule**

**Description:** Alert when a metric of an SNMP interface crosses a limit. With rule_id the rule is replaced (edit). Enterprise, administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK: rsp = { id } (the id of the saved rule); `-1` NOT_FOUND: rsp.error = rule_not_found (rule_id of an edit not found); `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not an administrator or no Enterprise license); `-5` INVALID_ARGUMENTS: rsp.error = invalid_rule (missing or not valid fields) or duplicate_rule (same device, port, metric, frequency and direction)

### POST /lua/pro/rest/v2/delete/snmp/device/rule.lua

**Delete an SNMP interface rule**

**Description:** Enterprise, administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` OK; `-1` NOT_FOUND: rsp.error = rule_not_found; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not an administrator or no Enterprise license); `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/snmp_debug.lua

**Download the SNMP cache of a device**

**Description:** Raw cached SNMP data of a device, as a text file attachment (debug). Administrators only.

**Produces:** `application/octet-stream`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of the SNMP device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/snmp/metric/interfaces.lua

**List the SNMP interfaces**

**Description:** Interfaces of all the devices or of one, with status, speeds, counters and usage, filtered and paged (without start/length the whole list). Requires access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Only the interfaces of this device | string |
| `start` | query | First row | integer |
| `length` | query | Number of rows | integer |
| `sort` | query | Column to sort by | string |
| `order` | query | asc or desc | string |
| `map_search` | query | Text to search | string |
| `snmp_status` | query | Operational status code | string |
| `snmp_admin_status` | query | Admin status code | string |
| `snmp_if_type` | query | Interface type | string |
| `err_counters_filter` | query | Only the interfaces with errors | boolean |
| `snmp_interface_role` | query | Interface role | string |
| `lldp_cdp_mode` | query | Only the interfaces with LLDP/CDP neighbours | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/metric/interfaces_filters.lua

**SNMP interfaces table filters**

**Description:** Filters of the SNMP interfaces table (status, type, role, errors). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Only the values of this device | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/metric/usage.lua

**SNMP interfaces usage**

**Description:** Usage of the SNMP interfaces included in the usage page (interfaces are excluded by default, see the interface configuration) in a time range, all the rows in one answer. Each record has device_name, ip, interface, ifid and, as {uplink, downlink} (values in %), min, max, average, last_value (last point with data), congestion_rate (% of the points with data above 75%), score (average usage level of the points with data, 1 for [0, 25]% up to 4 for (75, 100]%, x 12 points per hour), plus speed {uplink, downlink} in bit/s. The total is in recordsTotal. Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Only the interfaces of this device | string |
| `epoch_begin` | query | Begin of the range (epoch) | integer |
| `epoch_end` | query | End of the range (epoch) | integer |
| `map_search` | query | Text to search | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/snmp/metric/usage_chart.lua

**SNMP interfaces usage chart**

**Description:** Top 20 directions (uplink/downlink) of the SNMP interfaces included in the usage page by congestion rate (% of the points with data above 75%) in a time range: serie (congestion rates), labels (device, interface, direction) and metadata {ip, ifid}, in the same order. Only directions with a congestion rate above 0. Requires the SNMP capability and access to the system interface.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Only the interfaces of this device | string |
| `epoch_begin` | query | Begin of the range (epoch) | integer |
| `epoch_end` | query | End of the range (epoch) | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Observation Point"></a>

## Observation Point

### POST /lua/pro/rest/v2/delete/observation_point/stats.lua

**Remove an Observation Point stats**

**Description:** Remove Observation Point stats stored until now. If the Observation Point is no more seen on the network, even the entry is going to be deleted

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface identifier | integer |
| `observation_point` | formData | Identifier of the rule to delete | integer |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/observation_points/alias.lua

**Get the alias of an Observation Point**

**Description:** The alias of an Observation Point (empty string when not set)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `observation_point` | query | Observation Point ID | integer |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/interface/observation_points/stats.lua

**Get the observation points stats**

**Description:** Observation points seen on the interface: { observation_point, observation_point_alias, exporters, total_flows, hosts, throughput (bps), traffic (bytes) }. Pro only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/interface/observation_points/flowexporter_list.lua

**Get the flow exporters of an observation point**

**Description:** Flow exporters seen on an observation point: [{ exporter_ip, exporter_name (SNMP name with the SNMP capability, else the host name; null when it is the IP) }]. Empty list for an unknown observation point. Pro only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `obs_point` | query | Observation point identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/pro/rest/v2/set/observation_points/alias.lua

**Set the alias of an Observation Point**

**Description:** Set the alias of an Observation Point. Administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `alias` | formData | New Observation Point Alias (empty: remove it) | string |
| `observation_point` | formData | Observation Point ID | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

<a id="Pools"></a>

## Pools

### GET /lua/pro/rest/v2/get/pool/policy.lua

**Get the traffic policy of a host pool**

**Description:** Default policy and rules (nDPI markers) of a host pool, with the values usable in the rules (options: [{ value, label }] per kind) and the markers. Rules by kind: l7_proto (nDPI protocol id), l7_category (nDPI category id), host (host name or IP), country (ISO code), continent (code), risk (flow risk id), each [{ value, marker }]; marker = pass | 3 (slow) | 2 (slower) | drop (risks always drop). Pro (not nEdge), pools capability.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | query | Host pool identifier | integer |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-16` POOL_NOT_FOUND

### GET /lua/pro/rest/v2/export/pool/policy.lua

**Export pool policies**

**Description:** Export pool policies

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/set/pool/policy.lua

**Set the traffic policy of a host pool**

**Description:** Replaces the traffic policy (nDPI markers) of a host pool. Pro (not nEdge), pools capability, pool allowed to the user.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS (no JSON); `-6` INTERNAL_ERROR; `-7` BAD_FORMAT (not an object, or no pool_id)

### POST /lua/pro/rest/v2/set/pool/policy_autoconf.lua

**Configure the traffic policy of a host pool from its traffic**

**Description:** Replaces the traffic policy of a host pool with one built from the traffic seen by its hosts (default drop, the protocols and the top visited sites allowed). Pro (not nEdge), pools capability.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/add/host/pool.lua

**Add an host pool**

**Description:** Add an host pool with its members. Needs the Pools capability; users restricted to some pools cannot add pools. rsp: {pool_id} of the new pool.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool_name` | formData | Host pool name | string |
| `pool_members` | formData | Members separated by commas, each &lt;ip or network>/&lt;prefix>@&lt;vlan> or a MAC address (e.g. 192.168.1.10/32@0,10.0.0.0/24@0). Can be empty | string |

**Responses**

`0` POOL_ADDED_SUCCESSFULLY; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-13` ADD_POOL_FAILED; `-53` ADD_POOL_FAILED_TOO_MANY_POOLS; `-54` ADD_POOL_FAILED_TOO_MANY_POOLS_ENTERPRISE

### POST /lua/rest/v2/add/host/pool_member.lua

**Add a member to an host pool**

**Description:** Administrators only. A member of the Default pool (0) is moved there from any other pool.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` POOL_MEMBER_BOUND_SUCCESSFULLY; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-17` BIND_POOL_MEMBER_FAILED; `-18` BIND_POOL_MEMBER_ALREADY_BOUND: rsp = the pool that already has the member (remove it from there first)

### GET /lua/rest/v2/bind/host/pool/member.lua

**Bind a member to an host pool**

**Description:** Bind a member to an host pool

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | query | Host Pool ID | integer |
| `member` | query | IP/MAC/Network CIDR to add to the Host Pool ID | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-17` BIND_POOL_MEMBER_FAILED

### POST /lua/rest/v2/delete/host/pool.lua

**Delete an host pool**

**Description:** Delete an host pool. Needs the Pools capability and access to the pool.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | formData | Host pool id | integer |

**Responses**

`0` POOL_DELETED_SUCCESSFULLY; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-16` POOL_NOT_FOUND

### POST /lua/rest/v2/delete/host/pool_member.lua

**Remove a member from its host pool**

**Description:** Administrators only. The member goes back to the Default pool.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` POOL_MEMBER_BOUND_SUCCESSFULLY; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-17` BIND_POOL_MEMBER_FAILED

### POST /lua/rest/v2/delete/pools.lua

**Delete all pools for any available pool type**

**Description:** Delete all pools for any available pool type

**Produces:** `application/json`

**Responses**

`0` OK

### POST /lua/rest/v2/edit/host/pool.lua

**Edit an host pool**

**Description:** Rename an host pool and replace its members. Needs the Pools capability and access to the pool.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | formData | Host pool id | integer |
| `pool_name` | formData | Host pool name | string |
| `pool_members` | formData | Members separated by commas, each &lt;ip or network>/&lt;prefix>@&lt;vlan> or a MAC address. They replace the current members | string |

**Responses**

`0` POOL_EDITED_SUCCESSFULLY; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-14` EDIT_POOL_FAILED

### POST /lua/rest/v2/edit/host/pool/member.lua

**Replace a member of an host pool**

**Description:** Administrators only. old_member goes back to the Default pool, member joins the pool; refused (old_member unchanged) when member already belongs to another pool.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON object (with the csrf of the web session, not needed with API tokens) | object |

**Responses**

`0` POOL_MEMBER_BOUND_SUCCESSFULLY; `-3` NOT_GRANTED (administrators only); `-5` INVALID_ARGUMENTS; `-17` BIND_POOL_MEMBER_FAILED; `-18` BIND_POOL_MEMBER_ALREADY_BOUND: rsp = the pool that already has the member (remove it from there first)

### GET /lua/rest/v2/export/pool/config.lua

**Export the pools configuration as a JSON file**

**Description:** Export the configuration of all pools and dependencies (notifications, SNMP, active monitoring, checks

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/host/pool/members.lua

**Get all host pool members**

**Description:** Get all the members of a given host pool

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | query | Host Pool ID | integer |
| `member` | query | IP/MAC/Network CIDR to add to the Host Pool ID | string |

**Responses**

`0` OK; `-16` POOL_NOT_FOUND

### GET /lua/rest/v2/get/host/pool/list.lua

**Get the host pools of an interface with their traffic**

**Description:** The host pools with live statistics on the interface, only the pools the user can access. rsp is an array of records: pool_id, pool_name, hosts (active hosts), seen_since (seconds since the first packet), bytes_sent, bytes_rcvd, traffic (bytes), throughput (bps), members (as stored: &lt;address>/&lt;prefix>@&lt;vlan> or MAC), members_labels (members without the @&lt;vlan> suffix). recordsTotal/recordsFiltered: number of pools.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/host/pool/pools.lua

**Get one or all host pools**

**Description:** Get one or all host pools

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | query | Host Pool ID | integer |

**Responses**

`0` OK; `-16` POOL_NOT_FOUND

### GET /lua/rest/v2/get/host/pool_by_member.lua

**Get an host pool given a member**

**Description:** Get an host pool given a member

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `member` | query | IP/MAC/Network CIDR | string |
| `pool_name_only` | query | Return only the pool name (do not return pool details including members) | boolean |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/pools.lua

**Get all pools of any type**

**Description:** Get all pools defined for any available pool type

**Produces:** `application/json`

**Responses**

`0` OK

### POST /lua/rest/v2/import/pool/config.lua

**Import the pools configuration providing a JSON file**

**Description:** Import the configuration of all pools and dependencies (notifications, SNMP, active monitoring, checks

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### POST /lua/rest/v2/import/pool/host_pool/members.lua

**Import host pool members**

**Description:** Import host pool members

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `pool` | form | Pool identifier | integer |
| `host_pool_members` | form | A newline-separated list of host pool members | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

<a id="Traffic"></a>

## Traffic

### GET /lua/pro/rest/v2/get/db/historical_db_search.lua

**Get historical flows info**

**Description:** Get historical flows info

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (required unless any_interface=true) | integer |
| `any_interface` | query | Search the flows of all the interfaces (ifid is ignored) | boolean |
| `query_preset` | query | Query preset id (preset/consts.lua), empty for the raw flows | string |
| `aggregated` | query | Search the hourly aggregated flows (Enterprise XL) | boolean |
| `visible_columns` | query | Comma separated list of the columns to return | string |
| `sort` | query | Column to sort by | string |
| `order` | query | Sort order | string |
| `start` | query | Starting record (e.g. start=100, it will start returning records from the 101st) | integer |
| `length` | query | Maximum number of records to get: 1000 if not set, at most 10000 (a larger value returns 10000). totalRows is the number of flows matching the filters: read the others with start and length, or download all of them with /lua/pro/rest/v2/get/host/flows/download_flow_records.lua (CSV, no limit) | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7proto_master` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7cat` | query | Application category identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `flow_risk` | query | Flow risk identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `l4proto` | query | Transport protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `src2dst_dscp` | query | Client to Server DSCP identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `country` | query | Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_asn` | query | Client ASN identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_asn` | query | Server ASN identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_nw_latency` | query | Client network latency  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_nw_latency` | query | Server network latency  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `observation_point_id` | query | Observation point identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `src2dst_tcp_flags` | query | Client to Server TCP Flags (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `dst2src_tcp_flags` | query | Server to Client TCP Flags (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `mac` | query | MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_mac` | query | Client MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_mac` | query | Server MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `info` | query | Info field (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `bytes` | query | Total Bytes  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `packets` | query | Total Packets  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_proc_name` | query | Client process name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_proc_name` | query | Server process name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_user_name` | query | Client user name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_user_name` | query | Server user name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/connect/test.lua

**Test ntopng**

**Description:** Test ntopng  reachability and authentication

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v2/get/interface/nprobes/data.lua

**Get interface nProbe data**

**Description:** nProbe instances connected to the interface: probe_ip, probe_name, probe_source_id, probe_uuid, probe_public_ip, probe_instance_name, probe_version, probe_edition, probe_license ("" when none), probe_maintenance ("" when expired), probe_last_update (epoch), probe_interface ("" in collector mode), is_collector, flow_exporters, exporters_interfaces, exported_flows, dropped_flows, captured_packets, dropped_packets, is_in_memory, ntopng_interface, ifid, timeseries_enabled

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/network/discovery/discover.lua

**Get interface network discovery data**

**Description:** Get data regarding the network discovery done by an ntopng interface. Admin only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `operating_system` | query | Operating System identifier | integer |
| `device_type` | query | Device type identifier | integer |
| `manufacturer` | query | Manufacturer of the device | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="Timeseries"></a>

## Timeseries

### GET /lua/pro/rest/v2/get/db/ts.lua

**Return the number of flows in a period of time**

**Description:** Return the timeseries of number of flows in a period of time

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `alert_id` | query | Alert identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7proto` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7proto_master` | query | Application protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `l7cat` | query | Application category identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `flow_risk` | query | Flow risk identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `l4proto` | query | Transport protocol identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip_version` | query | IP version (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `ip` | query | IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_ip` | query | Client IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_ip` | query | Server IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `traffic_direction` | query | Traffic direction identifier, currently available: 0 -> remote only, 1 -> local only, 2 -> remote to local, 3 -> local to remote (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `name` | query | Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `cli_name` | query | Client Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `srv_name` | query | Server Hostname (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `network_name` | query | Network Name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `src2dst_dscp` | query | Client to Server DSCP identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_port` | query | Client port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_port` | query | Server port (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `country` | query | Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_country` | query | Client Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_country` | query | Server Country ID, e.g. IT (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_asn` | query | Client ASN identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_asn` | query | Server ASN identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_nw_latency` | query | Client network latency  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_nw_latency` | query | Server network latency  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `observation_point_id` | query | Observation point identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `probe_ip` | query | Probe IP (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `vlan_id` | query | VLAN ID  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `snmp_interface` | query | SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `input_snmp` | query | Input SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `output_snmp` | query | Output SNMP interface identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `src2dst_tcp_flags` | query | Client to Server TCP Flags (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `dst2src_tcp_flags` | query | Server to Client TCP Flags (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `severity` | query | Severity identifier (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `score` | query | Score (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `mac` | query | MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_mac` | query | Client MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_mac` | query | Server MAC Address (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `network` | query | Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_network` | query | Client Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_network` | query | Server Network identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `info` | query | Info field (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'in' -> contains, 'nin' -> not contains) | string |
| `bytes` | query | Total Bytes  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `packets` | query | Total Packets  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `host_pool_id` | query | Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `cli_host_pool_id` | query | Client Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `srv_host_pool_id` | query | Server Host Pool identifier  (format: 'id;eq', where 'id' is the amount of traffic and 'eq' stands for 'equal', currently available: 'eq' -> equal, 'neq' -> not equal, 'lt' -> lesser then, 'lte' -> lesser or equal then, 'gt' -> greater then, 'gte' -> greater or equal then | string |
| `l7_error_id` | query | Application layer error identifier (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_proc_name` | query | Client process name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_proc_name` | query | Server process name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `cli_user_name` | query | Client user name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |
| `srv_user_name` | query | Server user name (format: 'id;eq', where 'id' is the id and 'eq' stands for 'equal', currently available: 'eq', 'neq') | string |

**Responses**

`FILE` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### POST /lua/pro/rest/v2/get/timeseries/ts_multi.lua

**Return timeseries**

**Description:** Return the requested timeseries in the requested timeframe

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `limit` | query | Maximum number of timeseries points | number |
| `ts_compare` | query | Choices available: '30m', '1h', '1d'. A string reporting the timeframe of the timeseries to be compared to (e.g. '30m', means to return other then the timeserie requested, the 30 minutes before) | string |
| `ts_requests` | query | An array of timeseries to be returned, containing ts_query, ts_schema and tskey (e.g. [{ts_query: 'ifid:1,asn:199524', ts_schema: 'asn:traffic', tskey: '199524'}]; the explaination of these three parameters can be found into '/lua/rest/v2/get/timeseries/ts.lua' REST) | array |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v2/get/timeseries/ts.lua

**Get timeseries data**

**Description:** Get timeseries data

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | End time (epoch) | integer |
| `limit` | query | Maximum number of timeseries points | number |
| `initial_point` | query | A boolean used to return the first point of the timeseries or not | boolean |
| `ts_compare` | query | Choices available: '30m', '1h', '1d'. A string reporting the timeframe of the timeseries to be compared to (e.g. '30m', means to return other then the timeserie requested, the 30 minutes before) | string |
| `ts_query` | query | Containing the parameters used to find the timeserie in the following format, parameter:value;parameter:value;... (e.g. 'ifid:1;host:192.168.1.1') | string |
| `tskey` | query | Containing the timeseries key, whom the timeseries is referred to (e.g. if the timeserie is regarding the interface '7' or the host '192.168.1.1', then tskey is going to be '7' or '192.168.1.1') | string |
| `ts_schema` | query | Contains the timeserie schema (e.g. 'iface:traffic') | string |

**Responses**

`0` OK; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/get/timeseries/batch.lua

**Get several timeseries in one request**

**Description:** Runs every query of the JSON body on the same time range and returns one result per query id. Each result has the series, the metadata (schema, epoch_begin, epoch_step, label of the source: 'AS&lt;n> (&lt;name>)' for ASN queries, the interface name for interface queries), the measure_unit and, if the query failed, an error string.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | Time range and list of queries | object |

**Responses**

`0` OK

### GET /lua/rest/v2/get/timeseries/type/consts.lua

**Get available timeseries**

**Description:** Get all the available timeseries given a tag

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `query` | query | Tag used to retrieve the timeseries; currently available: iface, host, mac, subnet, asn, country, os, vlan, host_pool, pod, container, ht, system, profile, redis, influxdb, am, snmp_interface, snmp_device, obs_point, sflowdev_port, flowdev, flowdev_port | string |
| `host` | query | Host IP@VLAN, REQUIRED in case of timeseries regarding Host, SNMP or Flow devices | string |
| `asn` | query | ASN identifier, REQUIRED in case of timeseries regarding Autonomous Systems | integer |
| `pool` | query | Host Pool identifier, REQUIRED in case of timeseries regarding Host Pools | integer |
| `vlan` | query | VLAN identifier, REQUIRED in case of timeseries regarding VLANs | integer |
| `mac` | query | MAC address, REQUIRED in case of timeseries regarding MACs | string |
| `hash_table` | query | Hash table name (e.g. FlowHash), with query=ht: only the timeseries of that hash table | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

<a id="Flow Exporters"></a>

## Flow Exporters

### GET /lua/pro/rest/v2/get/exporters/get_exporters_interfaces_stats.lua

**Get the flow exporters interfaces**

**Description:** Interfaces of the flow exporters (routers, switches) sending flows to the interface, with their traffic since startup. Pro only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `interface_role` | query | Only the interfaces with this SNMP role (other, transit, ix, peering, customer_interface, internet_connectivity, internal_interface) | string |
| `deviceIP` | query | Only the interfaces of this flow exporter IP | string |

**Responses**

`0` OK: list of { exporter_ip, exporter_name, interface_id, interface_name, role: { value, label }, probe_source_id, exporter_source_id, ifid, bytes_sent, bytes_rcvd, total_bytes }; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/flowdevices/get_top_exporters_interfaces.lua

**Get the top flow exporters interfaces**

**Description:** The 7 flow exporters interfaces with the most traffic, same filters and fields as get_exporters_interfaces_stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `interface_role` | query | Only the interfaces with this SNMP role (other, transit, ix, peering, customer_interface, internet_connectivity, internal_interface) | string |
| `deviceIP` | query | Only the interfaces of this flow exporter IP | string |

**Responses**

`0` OK: list of at most 7 interfaces, by total_bytes desc; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/sflowdevice/interfaces.lua

**Get the interfaces of an sFlow device**

**Description:** Ports of an sFlow device from its sFlow counters, raw values: [{ ifindex, name (SNMP, null without it), has_snmp, has_timeseries, iftype, speed (bps), full_duplex, is_up, promisc, in_bytes, out_bytes, in_errors, out_errors, ratio (Counters/SNMP, null when not available, -1 not computable), ratio_status }], is_ratio_available. Pro only, needs the flow devices capability (SNMP fields: SNMP capability)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `ip` | query | sFlow device IP | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/sflowdevices/list.lua

**Get the sFlow devices**

**Description:** sFlow devices (agents exporting sFlow counters) seen on the interface: { ip, has_snmp, snmp_name, snmp_descr, snmp_location }. The SNMP fields need the SNMP capability. Pro only, needs the flow devices capability

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

<a id="Host"></a>

## Host

### GET /lua/pro/rest/v2/get/host/flows/data.lua

**Get host flows data**

**Description:** Given an host return the information used to create the sankey chart with all the flows information regarding that hosts (protocols, traffic, ecc.)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | formData | Host address | string |
| `hosts_type` | query | Currently available: local_only -> return only flows between local hosts, remote_only -> return only flows between remote hosts, local_origin_remote_target -> return only flows between local clients and remote servers, remote_origin_local_target -> return only flows between local servers and remote clients, all_hosts -> return all flows | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/fingerprint/data.lua

**Get the client fingerprints of a host**

**Description:** Given an host, return its JA4 (TLS) or HASSH (SSH) client fingerprints with the application name, the number of uses and the malicious flag

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `vlan` | query | VLAN ID | integer |
| `fingerprint_type` | query | The fingerprint type | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/host/l4/data.lua

**Get the host information about transport protocols**

**Description:** Given an host, return the transport protocols information (bytes sent, received, ...) of an host

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `vlan` | query | VLAN ID | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/host/l7/data.lua

**Get the nDPI applications or categories of a host**

**Description:** Given an host, return its nDPI applications (bytes sent, received, duration, share) or its nDPI categories (with their applications)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `vlan` | query | VLAN ID | integer |
| `view` | query | applications, or categories (any other value) | string |

**Responses**

`0` OK; `-4` INVALID_HOST

### GET /lua/rest/v2/get/host/processes/listening_ports.lua

**Get the host information about listening ports**

**Description:** Given an host, return the information about listening ports (transport level protocol, package and process that's currently running on that port)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |
| `vlan` | query | VLAN ID | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="Peers"></a>

## Peers

### GET /lua/rest/v2/get/host/no_tx_peers.lua

**Get RX-only host peers**

**Description:** Get list of host with RX-only traffic (i.e. no TX traffic sent)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

<a id="Top"></a>

## Top

### GET /lua/pro/rest/v2/get/host/top/local/sites.lua

**Get host top local sites**

**Description:** Get host top local sites

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | The IP address of the host | string |
| `vlan` | query | VLAN of the host (default 0) | integer |
| `hour` | query | Time range: current, last_5_min, day (yesterday) or the hour of today (0-23) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED (not ntopng Pro); `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/interface/top/l7_stats.lua

**Get interface top Layer-7 stats**

**Description:** Get interface top Layer-7 stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/interface/top/realtime_traffic.lua

**Get interface top traffic stats**

**Description:** Get interface top traffic stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET /lua/pro/rest/v2/get/interface/top/score.lua

**Get interface top score stats**

**Description:** Get interface top score stats

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="System"></a>

## System

### GET /lua/pro/rest/v2/get/infrastructure/data.lua

**Get infrastructure data**

**Description:** Get infrastructure data

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/delete/system/all_data.lua

**Purge all ntopng data**

**Description:** Request a full purge of the ClickHouse database and/or of the whole data directory (RRDs, etc.). Actual deletion is performed at the next restart as data is currently in use

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `clickhouse` | formData | Request the purge of the ClickHouse database | boolean |
| `datadir` | formData | Request the purge of the whole data directory (RRDs, etc.) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/ntopng/menu.lua

**Menu and shared page flags**

**Description:** Sidebar menu of the GUI and the flags shared by its pages (e.g. is_am_active, are_system_ts_enabled, are_alerts_enabled).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | string |

**Responses**

`0` OK

<a id="Sites"></a>

## Sites

### GET /lua/pro/rest/v2/get/interface/top/sites.lua

**Get interface top sites**

**Description:** Get the top sites for an interface

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v2/get/sites/list.lua

**Get the sites**

**Description:** List of the configured sites (id, name, description, latitude, longitude, networks, reserved). Needs an Enterprise M license (or higher).

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Maps"></a>

## Maps

### GET /lua/pro/rest/v2/get/interface/map/data.lua

**Get the graph of a service or periodicity map**

**Description:** Nodes (hosts, MACs: id, label, type local|remote|multicast|broadcast|mac, is_active, device group) and edges (from, to, value = number of services, bidirectional, protocols = up to 3 application names, num_protocols, status = worst service status) of the map, at most 2500 services (max_entry_reached).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `map` | query | Map | string |
| `host` | query | Only the services of this host: IP or MAC, with @vlan for the VLAN hosts | string |
| `vlan_id` | query | VLAN identifier | integer |
| `host_pool_id` | query | Host pool identifier | integer |
| `l7proto` | query | Application protocol name (e.g. DNS) | string |
| `network` | query | Local network identifier | integer |
| `service_status` | query | Service map only: 0 authorized, 1 unauthorized, 2 undecided | integer |
| `traffic_direction` | query | Periodicity map only: 0 local only, 1 remote only, 2 local client and remote server, 3 remote client and local server | integer |
| `unicast_only` | query | Only unicast hosts | boolean |
| `first_seen` | query | Only the services seen after this epoch | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE (missing ifid, or an interface the user cannot see) or NOT_ENABLED (behaviour analysis disabled on the interface); `-5` INVALID_ARGUMENTS (unknown map)

### GET /lua/pro/rest/v2/get/interface/map/table.lua

**Get the services of a service or periodicity map**

**Description:** One page of the services (view=standard: client, server, port, protocols, uses/observations, frequency, first/last seen, status) or of the hosts ranked by centrality (view=centrality: host, rank, edges). Peers are objects { host, ip, vlan, is_mac, name, active }. recordsTotal is the number of entries.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `map` | query | Map | string |
| `view` | query | Services or hosts ranking | string |
| `host` | query | Only the services of this host: IP or MAC, with @vlan for the VLAN hosts | string |
| `vlan_id` | query | VLAN identifier | integer |
| `host_pool_id` | query | Host pool identifier | integer |
| `l7proto` | query | Application protocol name (e.g. DNS) | string |
| `network` | query | Local network identifier | integer |
| `service_status` | query | Service map only: 0 authorized, 1 unauthorized, 2 undecided | integer |
| `traffic_direction` | query | Periodicity map only: 0 local only, 1 remote only, 2 local client and remote server, 3 remote client and local server | integer |
| `unicast_only` | query | Only unicast hosts | boolean |
| `first_seen` | query | Only the services seen after this epoch | integer |
| `start` | query | Row offset | integer |
| `length` | query | Rows per page | integer |
| `sort` | query | Sort column | string |
| `order` | query | Sort order | string |
| `map_search` | query | Text to search in the hosts | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE (missing ifid, or an interface the user cannot see) or NOT_ENABLED (behaviour analysis disabled on the interface); `-5` INVALID_ARGUMENTS (unknown map)

### GET /lua/pro/rest/v2/get/interface/map/filters.lua

**Get the filter values of a service or periodicity map**

**Description:** VLANs, application protocols, host pools ({ id, name }) and local networks ({ id, name }) seen by the map, optionally only for one host.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `map` | query | Map | string |
| `host` | query | Only the services of this host: IP or MAC, with @vlan for the VLAN hosts | string |
| `vlan_id` | query | VLAN identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE (missing ifid, or an interface the user cannot see) or NOT_ENABLED (behaviour analysis disabled on the interface); `-5` INVALID_ARGUMENTS (unknown map)

### POST /lua/pro/rest/v2/edit/interface/map/service_status.lua

**Set the status of a service of the service map**

**Description:** Marks a service of the service map as authorized (0), unauthorized (1) or undecided (2). Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE (missing ifid, or an interface the user cannot see) or NOT_ENABLED (behaviour analysis disabled on the interface); `-5` INVALID_ARGUMENTS (unknown map); `-3` NOT_GRANTED (administrators only)

### POST /lua/pro/rest/v2/delete/interface/map/data.lua

**Delete the services of a service or periodicity map**

**Description:** Deletes all the services learnt by the map of the interface: the map learns them again from the new traffic. Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-2` INVALID_INTERFACE (missing ifid, or an interface the user cannot see) or NOT_ENABLED (behaviour analysis disabled on the interface); `-5` INVALID_ARGUMENTS (unknown map); `-3` NOT_GRANTED (administrators only)

<a id="User"></a>

## User

### POST /lua/rest/v2/create/ntopng/api_token.lua

**Create an API token**

**Description:** Create an API token

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | An existing ntopng username | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

<a id="Checks"></a>

## Checks

### GET /lua/rest/v2/delete/application/application.lua

**Remove a custom protocol**

**Description:** If run ntopng using -p option, delete a custom protocol if it exists

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `protocol_alias` | form | Application Name | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/disable/check.lua

**Disables a check**

**Description:** Disables a check

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `check_subdir` | form | The check subdir | string |
| `script_key` | form | The key of the script | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/edit/application/application.lua

**Edit a custom protocol**

**Description:** If run ntopng using -p option, edit a custom protocol if it exists

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `protocol_alias` | form | Application Name | string |
| `category` | form | Category ID | integer |
| `l7_proto_id` | form | Application ID | integer |
| `custom_rules` | form | List of custom rules separated by commas | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/enable/check.lua

**Enables a check**

**Description:** Enables a check

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `check_subdir` | form | The check subdir | string |
| `script_key` | form | The key of the script | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/export/checks/config.lua

**Export Checks configuration**

**Description:** Export Checks configuration

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/checks/check_config.lua

**Get the configuration of a check**

**Description:** Return the configuration of a check: per-hook configuration, available severities, GUI metadata and the tags added to its alerts (and to the issues they open or update), with the tags that can be assigned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `check_subdir` | query | Family of the check (e.g. host, flow, interface) | string |
| `script_key` | query | Key of the check | string |
| `factory` | query | true to return the factory defaults (no tags) | boolean |

**Responses**

`0` OK. rsp: hooks, severities, gui, default_value, field_metadata, tags (array of tag ids, see rest/v2/get/tag/tags_list.lua for their definition); `-1` NOT_FOUND; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/checks/config.lua

**Get Checks configuration**

**Description:** Get checks configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download the data or not | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/rest/v2/get/checks/list.lua

**List the checks**

**Description:** Return the checks of a family with their status, severity and the tags added to their alerts

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `check_subdir` | query | Family of the checks (e.g. host, flow), all for every family | string |
| `ifid` | query | Interface ID | integer |
| `status` | query | all (default), enabled or disabled | string |

**Responses**

`0` OK. rsp: array of {key, subdir, title, description, category_key, category_icon, severity_key, severity_icon, is_enabled, enabled_hooks, tags (array of {id, name, color}), is_editable}; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/import/checks/config.lua

**Import Checks configuration**

**Description:** Import Checks configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `JSON` | form | The Checks configuration in JSON | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH

### GET /lua/rest/v2/reset/checks/config.lua

**Reset Checks configuration**

**Description:** Reset checks configuration

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/set/checks/check_config.lua

**Set the configuration of a check**

**Description:** Save the configuration of a check and the tags added to its alerts (and to the issues they open or update)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `check_subdir` | formData | Family of the check (e.g. host, flow, interface) | string |
| `script_key` | formData | Key of the check | string |
| `JSON` | formData | Per-hook configuration in JSON: {"&lt;hook>": {"enabled": true, "script_conf": {...&#125;&#125;} | string |
| `tag_ids` | formData | Comma-separated ids (0..63) of the tags added to the alerts of the check, empty for none. When missing, the current tags are kept | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### POST /lua/rest/v2/set/checks/config.lua

**Set Checks configuration**

**Description:** Set Checks configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `JSON` | form | Check configuration in JSON | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/set/host/notes.lua

**Set host custom notes**

**Description:** Given an host and a note, it is going to set that Note to the host

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `custom_notes` | form | Custom Host Note | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

<a id="Notification Endpoints"></a>

## Notification Endpoints

### POST /lua/rest/v2/delete/endpoints.lua

**Delete all defined notification endpoints and reset them to factory-defaults**

**Description:** Delete all defined notification endpoints and reset them to factory-defaults

**Produces:** `application/json`

**Responses**

`0` OK

<a id="Assets"></a>

## Assets

### POST /lua/pro/rest/v2/add/assets/assets.lua

**Import assets**

**Description:** Import the assets of a CSV file (as exported by export/assets/assets.lua). Enterprise M, administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `assets` | formData | CSV content | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-7` BAD_FORMAT

### GET /lua/pro/rest/v2/export/assets/assets.lua

**Export assets**

**Description:** The assets of every interface as CSV (is_snmp=true: the SNMP assets). Enterprise M, administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `is_snmp` | query | true for the SNMP assets | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/set/assets/wazuh_info.lua

**Merge the Wazuh agents info into the assets**

**Description:** Read the agents from the Wazuh API and update the matching assets of the interface. Enterprise M, administrators only, needs the Wazuh API configured

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/delete/host/asset.lua

**Delete assets**

**Description:** Delete one asset (serial_key = its key), all the assets (serial_key = all), or the ones not seen since an epoch (serial_key = epoch). The journal entries of the deleted assets are deleted too (all the journal of the interface for all the assets), then the journal records the deletion: one entry for one asset, a single entry with their number (no asset key) for several assets deleted at once. Administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | formData | Interface identifier | integer |
| `serial_key` | formData | Asset key, all, or an epoch | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/delete/host/asset_tag.lua

**Remove a tag from an asset**

**Description:** Remove a user-defined tag (32-63) from an asset and from all its hosts (the hosts of its IP on every VLAN of the asset, also the inactive ones). The journal of the assets records the removal. The built-in tags (0-31) are set by the hosts and cannot be removed. Enterprise M, administrators only

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-1` NOT_FOUND (no such asset, or the asset has not the tag); `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/pro/rest/v2/get/host/assets.lua

**Get the assets inventory**

**Description:** Assets of the interface (page=snmp: the SNMP assets of the system interface), paginated. The VLAN is not part of the identity of a host asset: host.vlans [{ id, name, online }] lists the VLANs where its IP has been seen, with the state of the host of each one (the asset is online when any of them is); host.vlan is the VLAN seen last. Enterprise M only. Needs the historical flows capability (non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `page` | query | snmp: the SNMP assets | string |
| `start` | query | First record | integer |
| `length` | query | Number of records | integer |
| `sort` | query | Column (ip_address, name, mac_address, vlan, network, device_type, manufacturer, first_seen, last_seen, os (the OS tag), model, status, switch_ip, switch_port) | string |
| `order` | query | asc or desc | string |
| `manufacturer` | query | Filter | string |
| `vlan` | query | Filter: one of the VLANs of the asset | integer |
| `device_type` | query | Filter | integer |
| `network` | query | Filter | integer |
| `status` | query | 0 online, 1 offline | string |
| `os_type` | query | Filter on the OS learnt by the host (not the OS tag: see label) | string |
| `server_type` | query | Filter | integer |
| `switch_ip` | query | Filter | string |
| `switch_port` | query | Filter | integer |
| `label` | query | Tag id | integer |
| `map_search` | query | Text searched in IP, name, MAC | string |
| `wazuh_available` | query | 0 with Wazuh info, 1 without | integer |
| `site_id` | query | Site | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/host/assets_total_traffic.lua

**Get the traffic of the assets**

**Description:** Local and remote traffic (bytes) of each asset with traffic in a time interval: host, name, online, local_traffic, remote_traffic. Enterprise: the assets of the inventory (needs the historical flows capability for non-admin users); Pro: the local hosts. epoch_begin equal to epoch_end reads the live counters.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `ts_schema` | query | Timeseries schema of the totals (default: host:local_traffic) | string |
| `epoch_begin` | query | Start of the interval, epoch (default: epoch_end - 3600) | integer |
| `epoch_end` | query | End of the interval, epoch (default: now) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/host/assets_filters.lua

**Get the assets inventory filters**

**Description:** Filters of the assets table with their options (as the other *_filters REST). Enterprise M only. Needs the historical flows capability (non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `site_id` | query | Adds the Site filter | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/host/assets_journal.lua

**Get the assets journal entries**

**Description:** Entries of the assets journal in a time interval, newest first: event_time and created_time (epochs), asset (key, type, ip, vlan, name; empty key for an event of several assets at once: a deletion, the conversion of the assets recorded per VLAN by an older version), who, action, subaction, message. Enterprise L, assets inventory and journal preference enabled. Needs the historical flows capability (non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `serial_key` | query | Key of an asset: only its entries (default: all the assets of the interface) | string |
| `epoch_begin` | query | Begin of the interval, on the time of the events (epoch, default: epoch_end - 1 day) | integer |
| `epoch_end` | query | End of the interval, on the time of the events (epoch, default: now) | integer |
| `action` | query | Only the entries with this action (Baseline, New, Update, Delete, Manual) | string |
| `who` | query | Only the entries caused by this user (ntopng for the automatic events) | string |
| `subaction` | query | Only the entries about this subaction (e.g. os, tag, mac) | string |
| `start` | query | Offset of the first entry of the page (default: 0) | integer |
| `length` | query | Number of entries of the page (default: all the entries) | integer |
| `sort` | query | Column to sort by: event_time (default), created_time, asset, action, subaction, who | string |
| `order` | query | Sort order: asc or desc (default) | string |
| `map_search` | query | Free text (case insensitive): key (IP of the asset), who, action, subaction and message of the entries | string |

**Responses**

`0` OK: the entries of the page in rsp, the number of the entries matching (all the pages) in recordsTotal and recordsFiltered; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/host/assets_journal_filters.lua

**Get the assets journal filters**

**Description:** Filters of the assets journal table (action, who, subaction) with their options, as the other *_filters REST: the values of the entries in the interval. Enterprise L, assets inventory and journal preference enabled. Needs the historical flows capability (non-admin users).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `serial_key` | query | Key of an asset: only its entries (default: all the assets of the interface) | string |
| `epoch_begin` | query | Begin of the interval, on the time of the events (epoch, default: epoch_end - 1 day) | integer |
| `epoch_end` | query | End of the interval, on the time of the events (epoch, default: now) | integer |
| `action` | query | Only the entries with this action (Baseline, New, Update, Delete, Manual) | string |
| `who` | query | Only the entries caused by this user (ntopng for the automatic events) | string |
| `subaction` | query | Only the entries about this subaction (e.g. os, tag, mac) | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

<a id="L7 Application Categories"></a>

## L7 Application Categories

### POST /lua/rest/v2/edit/category/category.lua

**Change the custom hosts for a specific category**

**Description:** Given a category, an alias for the category and a list of hosts, networks or domain names, separated by comma, it is going to change the alias of the category and aggregate the traffic done by those hosts into the category

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `category` | formData | Category, formatted as cat_{id}, where ID is the ID of the category | string |
| `custom_hosts` | formData | List of Hosts, Networks, Domain Names, separated by comma | string |
| `category_alias` | formData | Alias of the Category | string |

**Responses**

`0` OK

### GET /lua/rest/v2/get/l7/category/consts.lua

**Get L7 application category constants**

**Description:** L7 application category names and integer identifiers

**Produces:** `application/json`

**Responses**

`0` OK

<a id="Configuration"></a>

## Configuration

### POST /lua/rest/v2/edit/ntopng/incr_flows.lua

**Double the maximum number of flows managed by ntopng**

**Description:** Double the maximum number of flows managed by ntopng

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-7` BAD_FORMAT

### POST /lua/rest/v2/edit/ntopng/incr_hosts.lua

**Double the maximum number of hosts managed by ntopng**

**Description:** Double the maximum number of hosts managed by ntopng

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-7` BAD_FORMAT

<a id="All"></a>

## All

### GET /lua/rest/v2/export/all/config.lua

**Export all configurations as a JSON file**

**Description:** Export all configurations including Pools, Active Monitoring, Notifications (Endpoints and Recipients), Checks, SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/import/all/config.lua

**Import all configurations providing a JSON file**

**Description:** Import all configurations including Pools, Active Monitoring, Notifications (Endpoints and Recipients), Checks, SNMP devices

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### POST /lua/rest/v2/reset/all/config.lua

**Reset all configurations**

**Description:** Reset all configurations

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Notifications"></a>

## Notifications

### GET /lua/rest/v2/export/notifications/config.lua

**Export the notifications configuration as a JSON file**

**Description:** Export the configuration for endpoints, recipients and notification policies (endpoints: the endpoints with their recipients; policies: the policies, with the names of their recipients)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/import/notifications/config.lua

**Import the notifications configuration providing a JSON file**

**Description:** Import the configuration for endpoints, recipients and notification policies, as exported. A configuration exported before the notification policies (the endpoints only) is accepted too: the filters of each recipient become a policy

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### GET /lua/rest/v2/reset/notifications/config.lua

**Reset Notifications configuration**

**Description:** Reset notifications configuration

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id=""></a>

## 

### GET /lua/rest/v2/export/snmp/config.lua

**Export the SNMP configuration as a JSON file**

**Description:** Export the configuration for the SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/import/snmp/config.lua

**Import the SNMP configuration providing a JSON file**

**Description:** Import the configuration for the SNMP devices

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

<a id="Autonomous System"></a>

## Autonomous System

### POST /lua/rest/v2/get/asn/asn_info.lua

**Get Autonomous systems data**

**Description:** Return the ASN data ntopng collected from analyzing the network. If an ASN is given, then return the data regarding the requested ASN

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `asn` | formData | Autonomous System ID | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/get/asn/asn_name.lua

**Get Autonomous systems name**

**Description:** Return the ASN name given an IP

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ip` | query | IP Address | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

<a id="Category"></a>

## Category

### GET /lua/rest/v2/get/category/list.lua

**Get category information**

**Description:** Get all the category information available

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="Country"></a>

## Country

### POST /lua/rest/v2/get/country/country_name.lua

**Get Country Name**

**Description:** Return the Country name given a country code

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `country_id` | query | Country Code | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

<a id="DNS"></a>

## DNS

### GET /lua/rest/v2/get/dns/resolve.lua

**Resolve an host name into an IP address**

**Description:** Resolve an host name into an IP address

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `hostname` | query | The host name to be resolved | string |

**Responses**

`0` OK; `-9` NAME_RESOLUTION_FAILED

<a id="ARP"></a>

## ARP

### GET /lua/rest/v2/get/interface/arp.lua

**Get interface ARP info**

**Description:** Get interface ARP info

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="L4 Protocols"></a>

## L4 Protocols

### GET /lua/rest/v2/get/l4/protocol/consts.lua

**Get L4 protocol constants**

**Description:** L4 protocol names and integer identifiers

**Produces:** `application/json`

**Responses**

`0` OK

<a id="L7 Application Protocols"></a>

## L7 Application Protocols

### GET /lua/rest/v2/get/l7/application/consts.lua

**Get L7 application protocol constants**

**Description:** L7 application protocol names and integer identifiers

**Produces:** `application/json`

**Responses**

`0` OK

<a id="Macs"></a>

## Macs

### GET /lua/rest/v2/get/mac/data.lua

**Get Macs traffic information**

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `mac` | query | Mac Address to get information | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE

### GET /lua/rest/v2/get/mac/overview.lua

**Get the overview of a MAC address**

**Description:** An active MAC address: name, device type, model, DHCP fingerprint, host pool, first host and number of hosts, first observed, last counters reset, events, and the traffic counters (seen.first/last, bytes/packets/dhcp sent and rcvd, ARP requests/replies, flows.dropped). counters=true: only the counters.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | MAC address (e.g. AA:BB:CC:DD:EE:FF) | string |
| `counters` | query | true: only the live counters | boolean |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/mac/snmp_location.lua

**Get where a MAC address was seen on the SNMP devices**

**Description:** The access ports and the trunk ports of the monitored SNMP devices (Bridge MIB) where the MAC address was seen: device IP and name, port index and name, trunk. Enterprise M.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | MAC address (e.g. AA:BB:CC:DD:EE:FF) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/mac/config.lua

**Get the settings of a MAC address**

**Description:** Alias, device type and host pool of the MAC address, with the pools that can be chosen (none on view interfaces). Administrators only.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | MAC address (e.g. AA:BB:CC:DD:EE:FF) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### POST /lua/rest/v2/set/mac/config.lua

**Set the settings of a MAC address**

**Description:** Saves alias (empty: removed), device type (0-12, see discover_utils) and host pool (not on view interfaces) of a MAC address. Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR (the pool member could not be bound)

### POST /lua/rest/v2/set/mac/reset_stats.lua

**Reset the counters of a MAC address**

**Description:** Resets the traffic counters of an active MAC address. Administrators only.

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body |  | object |

**Responses**

`0` OK; `-1` NOT_FOUND; `-3` NOT_GRANTED; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/mac/macs_list.lua

**Get the active MAC addresses of an interface**

**Description:** One page of the active MACs. rsp is an array of records: mac, manufacturer (with the [model] when known), device_type {id, device_type_label, &lt;type name>: true}, name {has_name, name | num_hosts, host_label}, hosts, arp (ARP packets sent + received), seen_since (epoch of the first packet), bytes_sent, bytes_rcvd, traffic (bytes), throughput + throughput_type (bps or pps, per the throughput preference), location (nEdge only). recordsTotal/recordsFiltered: MACs matching the filters.

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |
| `start` | query | Offset of the first MAC returned (default 0) | integer |
| `length` | query | Number of MACs returned (default: all) | integer |
| `sort` | query | Sort column: mac, manufacturer, hosts, arp, seen_since, throughput, traffic (default mac) | string |
| `order` | query | Sort order: asc or desc (default asc) | string |
| `map_search` | query | Free-text search on the MAC address and manufacturer | string |
| `devices_mode` | query | source_macs_only: only the MACs that sent traffic (inactive_macs_only is handled as source_macs_only) | string |
| `manufacturer` | query | Manufacturer name (exact match) | string |
| `device_type` | query | Device type id | integer |
| `location` | query | nEdge only: lan, wan or unknown | string |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="Networks"></a>

## Networks

### GET /lua/rest/v2/get/network/networks.lua

**Return list of networks**

**Description:** Return the list of all networks

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK

### POST /lua/rest/v2/set/network/alias.lua

**Set network alias**

**Description:** Set network custom name

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `network_cidr` | formData | Network CIDR | string |
| `custom_name` | formData | Custom name | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

<a id="License"></a>

## License

### GET /lua/rest/v2/get/ntopng/license.lua

**Get license information for the current ntopng instance**

**Description:** Get license information for the current ntopng instance, including SystemId and license validity/expiry

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/rest/v2/set/ntopng/license.lua

**Set the ntopng license key**

**Description:** Set the ntopng license key

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ntopng_license` |  | The license key | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

<a id="VLANs"></a>

## VLANs

### POST /lua/rest/v2/set/vlan/alias.lua

**Set the alias of a VLAN**

**Description:** Set the alias of a VLAN; an empty alias removes it. Administrators only

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `vlan` | formData | VLAN id (1-4095) | integer |
| `alias` | formData | New alias (empty: remove it) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/vlan/alias.lua

**Get the alias of a VLAN**

**Description:** The alias of a VLAN (empty string when not set)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `vlan` | query | VLAN id (1-4095) | integer |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v2/get/vlan/list.lua

**Get the VLANs of an interface**

**Description:** The VLANs seen on the interface, untagged traffic (vlan_id 0) included. rsp is an array of records: vlan_id, vlan_alias (only when an alias is set), is_untagged, num_hosts (active hosts), score, seen_since (seconds since the first packet), bytes_sent, bytes_rcvd, traffic (bytes), throughput_bps, throughput_pps. recordsTotal/recordsFiltered: number of VLANs. Any user can call it (interface restrictions apply).

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier (default: the current interface) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="Devices"></a>

## Devices

### POST /lua/rest/v2/set/device/alias.lua

**Set device alias**

**Description:** Set device custom name

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `device` | formData | Device MAC Address | string |
| `custom_name` | formData | Custom name | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

<a id="REST API"></a>

## REST API

### GET /lua/rest/version.lua

**Get supported and current REST API versions**

**Description:** Return all the supported REST API versions and the current REST API version used

**Produces:** `application/json`

**Responses**

`0` OK
