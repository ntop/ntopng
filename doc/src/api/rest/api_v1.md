---
title: "RESTful API v1 Specification"
description: "The HTTP/HTTPS authentication should be used, for example with curl it is possible to specify username and password with"
outline: [2, 3]
lastUpdated: 2021-02-16T08:15:10+01:00
---
# RESTful API v1 Specification {#restful-api-v1-specification}

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
curl -s -u admin:admin "http://192.168.1.1:3000/lua/rest/v1/get/host/data.lua?ifid=1&host=192.168.1.2"
```

or the below `curl` command line using POST:

```bash
curl -s -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.2"}' "http://192.168.1.1:3000/lua/rest/v1/get/host/data.lua"
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

<a id="Interfaces"></a>

## Interfaces

### GET /lua/rest/v1/get/interface/data.lua

**Get interface data**

**Description:** Interface data is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/interface/bcast_domains.lua

**Get interface broadcast domains**

**Description:** Interface broadcast domains as detected from ARP traffic and broadcast traffic are returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/interface/address.lua

**Get interface IP addresses**

**Description:** List of interface IP addresses is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/interface/l7/stats.lua

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

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/interface/dscp/stats.lua

**Get IP DSCP statistics for an interface**

**Description:** DSCP statistics

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/ntopng/interfaces.lua

**Get ntopng actively monitored interfaces names and ids**

**Description:** Interface name and integer interface id for each actively monitored ntopng interface

**Produces:** `application/json`

**Responses**

`0` OK

<a id="Hosts"></a>

## Hosts

### GET /lua/rest/v1/get/host/active.lua

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

### GET /lua/rest/v1/get/host/interfaces.lua

**Get host interfaces**

**Description:** All interface ids of a given host are returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | Host address | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET /lua/rest/v1/get/host/data.lua

**Get host data**

**Description:** Host data is returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `host` | query | Host address | string |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT; `-8` BAD_CONTENT

### GET /lua/rest/v1/get/host/custom_data.lua

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

### GET /lua/rest/v1/get/host/l7/stats.lua

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

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/host/dscp/stats.lua

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

### POST /lua/rest/v1/set/host/alias.lua

**Set host alias**

**Description:** Set hsot custom name

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | formData | Host address | string |
| `custom_name` | formData | Custom name | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### GET lua/pro/rest/v1/get/interface/top/local/talkers.lua

**Get Top local talkers**

**Description:** Get the Top 10 local talkers

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | number |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

### GET lua/pro/rest/v1/get/interface/top/remote/talkers.lua

**Get Top remote talkers**

**Description:** Get the Top 10 remote talkers

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface ID | number |

**Responses**

`0` OK; `-2` INVALID_INTERFACE

<a id="Alerts"></a>

## Alerts

### GET /lua/rest/v1/get/alert/data.lua

**Get alerts data**

**Description:** Alerts are returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `status` | query | Status filter (historical, historical-flows, engaged) | string |
| `epoch_begin` | query | Start time (epoch) (optional) | integer |
| `epoch_end` | query | Start time (epoch) (optional) | integer |
| `alert_type` | query | Alert Type (optional) | integer |
| `alert_severity` | query | Alert Severity (optional) | integer |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT; `-8` BAD_CONTENT

### GET /lua/rest/v1/get/alert/ts.lua

**Get alerts timeseries**

**Description:** Number of alerts per hour divided by day are returned

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `status` | query | Status filter (historical, historical-flows) | string |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | Start time (epoch) | integer |
| `alert_type` | query | Alert Type (optional) | integer |
| `alert_severity` | query | Alert Severity (optional) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/alert/type/consts.lua

**Get alert type constants**

**Description:** Alert type string and integer alert key for each defined alert

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v1/get/alert/severity/consts.lua

**Get alert severity constants**

**Description:** Alert severity string and integer severity id for each defined severity

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
| `epoch_end` | query | Start time (epoch) | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

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

<a id="Flows"></a>

## Flows

### GET /lua/rest/v1/get/flow/active.lua

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

### GET /lua/rest/v1/get/flow/l4/counters.lua

**Get flow counters for L4 protocols**

**Description:** Number of active flows per L4 protocol

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/rest/v1/get/flow/l7/counters.lua

**Get flow counters for L7 protocols**

**Description:** Number of active flows per L7 application protocol

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v1/get/db/flows.lua

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
| `where_clause` | query | Where clause (default: none) | string |
| `maxhits_clause` | query | Max hits (default: 10) | integer |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### GET /lua/pro/rest/v1/get/db/topk_flows.lua

**Get Top-K flows data. Columns include (but are not limited to) IP_PROTOCOL_VERSION, FLOW_TIME, FIRST_SEEN, LAST_SEEN, VLAN_ID, PACKETS, TOTAL_BYTES, SRC2DST_BYTES, DST2SRC_BYTES, IPV4_SRC_ADDR, IPV4_DST_ADDR, IPV6_SRC_ADDR, IPV6_DST_ADDR, PROTOCOL, L7_PROTO**

**Description:** Executes a top-k query to the flows database

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `begin_time_clause` | query | Start time (epoch) | integer |
| `end_time_clause` | query | Start time (epoch) | integer |
| `select_keys_clause` | query | Select comma-separated keys list (default: IPV4_SRC_ADDR,IPV4_DST_ADDR,L7_PROTO) | string |
| `select_values_clause` | query | Select value (default: BYTES) | string |
| `where_clause` | query | Where clause (default: none) | string |
| `topk_clause` | query | Top-K clause (default: SUM) | string |
| `approx_search` | query | Approximate search (default: true) | string |
| `maxhits_clause` | query | Max hits (default: 10) | integer |

**Responses**

`0` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

<a id="PCAP"></a>

## PCAP

### GET /lua/rest/v1/get/pcap/live_extraction.lua

**Live PCAP traffic extraction**

**Description:** Raw PCAP data is returned

**Produces:** `application/vnd.tcpdump.pcap`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |
| `epoch_begin` | query | Start time (epoch) | integer |
| `epoch_end` | query | Start time (epoch) | integer |
| `bpf_filter` | query | BPF filter | string |

**Responses**

`FILE` OK; `-1` NOT_FOUND; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

<a id="Users"></a>

## Users

### POST lua/rest/v1/get/ntopng/users.lua

**Read all configured ntopng users**

**Description:** Read all configured ntopng users

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/add/ntopng/user.lua

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
| `user_language` | formData | Language (en, it, de, jp, pt, cz) | string |
| `allow_pcap_download` | formData | Allow PCAPs download (1 to allow) | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-19` PASSWORD_MISMATCH; `-20` ADD_USER_FAILED; `-23` USER_ALREADY_EXISTING

### POST lua/rest/v1/delete/ntopng/user.lua

**Delete ntopng user**

**Description:** Delete a ntopng user

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |

**Responses**

`-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-21` DELETE_USER_FAILED

### POST lua/rest/v1/edit/ntopng/user.lua

**Edit a ntopng user**

**Description:** Edit an existing ntopng user

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |
| `user_role` | formData | User role (unprivileged / administrator) | string |
| `allowed_networks` | formData | Allowed networks (e.g. 0.0.0.0/0,::/0) | string |
| `allowed_interface` | formData | Allowed interfaces (empty for all) | string |
| `user_language` | formData | Language (en, it, de, jp, pt, cz) | string |
| `allow_pcap_download` | formData | Allow PCAPs download (1 to allow) | string |

**Responses**

`-5` INVALID_ARGUMENTS; `-21` DELETE_USER_FAILED; `-23` USER_DOES_NOT_EXIST; `-24` EDIT_USER_FAILED

### POST lua/rest/v1/create/ntopng/session.lua

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

### POST lua/rest/v1/get/ntopng/session.lua

**Create a new ntopng user session Cookie (same as create/ntopng/session.lua)**

**Description:** Generate a new user session to be used as session Cookie

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `username` | formData | Username | string |
| `auth_session_duration` | formData | Session duration (seconds). Default: 0 (no expiration). | integer |

**Responses**

`-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS

<a id="Infrastructures"></a>

## Infrastructures

### GET /lua/pro/rest/v1/get/infrastructure/instance.lua

**Get one or all infrastructure configs**

**Description:** Get one or all infrastructure configs

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |
| `` |  | Add statistics collected by the active monitoring module |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-32` INFRASTRUCTURE_INSTANCE_NOT_FOUND

### POST /lua/pro/rest/v1/add/infrastructure/instance.lua

**Add a new infrastructure configuration**

**Description:** Add a new infrastructure configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `url` |  | The URL of the ntopng in the infrastructure | string |
| `alias` |  | An alias for the infrastructure | string |
| `token` |  | The REST API Token for the authentication | string |
| `rtt_threshold` |  | RTT threshold used by the active monitoring | int32 |
| `bandwidth_threshold` |  | Bandwidth threshold used by the active monitoring | int32 |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-34` INFRASTRUCTURE_INSTANCE_EMPTY_ALIAS; `-35` INFRASTRUCTURE_INSTANCE_EMPTY_URL; `-36` INFRASTRUCTURE_INSTANCE_EMPTY_TOKEN; `-37` INFRASTRUCTURE_INSTANCE_EMPTY_RTT_THRESHOLD; `-39` INFRASTRUCTURE_INSTANCE_SAME_ALIAS; `-40` INFRASTRUCTURE_INSTANCE_SAME_URL; `-41` INFRASTRUCTURE_INSTANCE_SAME_TOKEN; `-42` INFRASTRUCTURE_INSTANCE_ALREADY_EXISTING; `-47` INFRASTRUCTURE_INSTANCE_EMPTY_BANDWIDTH_THRESHOLD

### POST /lua/pro/rest/v1/edit/infrastructure/instance.lua

**Edit an existing infrastructure configuration**

**Description:** Edit an existing infrastructure configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `instance_id` |  | The ID of the infrastructure configuration to edit | string |
| `url` |  | The URL of the ntopng in the infrastructure | string |
| `alias` |  | An alias for the infrastructure | string |
| `token` |  | The REST API Token for the authentication | string |
| `rtt_threshold` |  | RTT threshold used by the active monitoring | int32 |
| `bandwidth_threshold` |  | Bandwidth threshold used by the active monitoring | int32 |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-32` INFRASTRUCTURE_INSTANCE_NOT_FOUND; `-33` INFRASTRUCTURE_INSTANCE_EMPTY_ID; `-34` INFRASTRUCTURE_INSTANCE_EMPTY_ALIAS; `-35` INFRASTRUCTURE_INSTANCE_EMPTY_URL; `-36` INFRASTRUCTURE_INSTANCE_EMPTY_TOKEN; `-37` INFRASTRUCTURE_INSTANCE_EMPTY_RTT_THRESHOLD; `-39` INFRASTRUCTURE_INSTANCE_SAME_ALIAS; `-40` INFRASTRUCTURE_INSTANCE_SAME_URL; `-41` INFRASTRUCTURE_INSTANCE_SAME_TOKEN; `-47` INFRASTRUCTURE_INSTANCE_EMPTY_BANDWIDTH_THRESHOLD

### POST /lua/pro/rest/v1/delete/infrastructure/instance.lua

**Delete an existing infrastructure configuration**

**Description:** Delete an existing infrastructure configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `instance_id` |  | The ID of the infrastructure to delete | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-32` INFRASTRUCTURE_INSTANCE_NOT_FOUND; `-33` INFRASTRUCTURE_INSTANCE_EMPTY_ID

### POST lua/rest/v1/import/infrastructure/config.lua

**Import the Infrastructure configuration providing a JSON file**

**Description:** Import the configuration for all infrastructure configurations

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### POST lua/rest/v1/export/infrastructure/config.lua

**Export the Infrastructure configurations as a JSON file**

**Description:** Export the configuration for the infrastructure configurations

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/reset/infrastructure/config.lua

**Reset all infrastructure configurations**

**Description:** Reset all infrastructure configurations

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="L4 Protocols"></a>

## L4 Protocols

### GET /lua/rest/v1/get/l4/protocol/consts.lua

**Get L4 protocol constants**

**Description:** L4 protocol names and integer identifiers

**Produces:** `application/json`

**Responses**

`0` OK

<a id="L7 Application Protocols"></a>

## L7 Application Protocols

### GET /lua/rest/v1/get/l7/application/consts.lua

**Get L7 application protocol constants**

**Description:** L7 application protocol names and integer identifiers

**Produces:** `application/json`

**Responses**

`0` OK

<a id="L7 Application Categories"></a>

## L7 Application Categories

### GET /lua/rest/v1/get/l7/category/consts.lua

**Get L7 application category constants**

**Description:** L7 application category names and integer identifiers

**Produces:** `application/json`

**Responses**

`0` OK

<a id="SNMP"></a>

## SNMP

### GET lua/pro/rest/v1/add/snmp/device.lua

**Add SNMP devices**

**Description:** Add devices to the monitored SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `snmp_host` | query | IP address or symbolic name of and an SNMP device | string |
| `snmp_read_community` | query | The SNMP read community to use (SNMP v1/v2c only) | string |
| `snmp_write_community` | query | The SNMP write community to use (SNMP v1/v2c only) | string |
| `snmp_version` | query | The SNMP version to use: 2 (SNMP v3), 1 (v2c) or 0 (v1) | string |
| `snmp_level` | query | Used only with SNMP v3: noAuthNoPriv, authNoPriv, or authPriv) | string |
| `snmp_auth_protocol` | query | Used only with SNMP v3 and level not set to noAuthNoPriv: MD5 or SHA | string |
| `snmp_auth_passphrase` | query | Used only with SNMP v3 and level not set to noAuthNoPriv: 8 chars+ passphrase | string |
| `snmp_privacy_protocol` | query | Used only with SNMP v3 and level set to autPriv: DES or AES | string |
| `snmp_privacy_passphrase` | query | Used only with SNMP v3 and level set to autPriv: 8 chars+ passphrase | string |
| `cidr` | query | Either 24 or 32. If 32, snmp_host is treated as single host. If 24 snmp_host is treated as as CIDR address | string |

**Responses**

`-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-9` NAME_RESOLUTION_FAILED; `-10` SNMP_DEVICE_ALREADY_ADDED; `-11` SNMP_DEVICE_UNREACHABLE; `-12` NO_SNMP_DEVICE_DISCOVERED

### GET lua/pro/rest/v1/edit/snmp/device/device.lua

**Edit a SNMP device**

**Description:** Edit an existing monitored SNMP device

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `snmp_host` | query | IP address or symbolic name of and an SNMP device | string |
| `snmp_read_community` | query | The SNMP read community to use (SNMP v1/v2c only) | string |
| `snmp_write_community` | query | The SNMP write community to use (SNMP v1/v2c only) | string |
| `snmp_version` | query | The SNMP version to use: 2 (SNMP v3), 1 (v2c) or 0 (v1) | string |
| `snmp_level` | query | Used only with SNMP v3: noAuthNoPriv, authNoPriv, or authPriv) | string |
| `snmp_auth_protocol` | query | Used only with SNMP v3 and level not set to noAuthNoPriv: MD5 or SHA | string |
| `snmp_auth_passphrase` | query | Used only with SNMP v3 and level not set to noAuthNoPriv: 8 chars+ passphrase | string |
| `snmp_privacy_protocol` | query | Used only with SNMP v3 and level set to autPriv: DES or AES | string |
| `snmp_privacy_passphrase` | query | Used only with SNMP v3 and level set to autPriv: 8 chars+ passphrase | string |

**Responses**

`-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-9` NAME_RESOLUTION_FAILED; `-10` SNMP_DEVICE_ALREADY_ADDED; `-11` SNMP_DEVICE_UNREACHABLE; `-12` NO_SNMP_DEVICE_DISCOVERED; `-22` SNMP_UNKNOWN_DEVICE

### GET lua/pro/rest/v1/change/snmp/device/interface/status.lua

**Change SNMP device interface status**

**Description:** Change the status of an SNMP device in terface to up or down

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `host` | query | IP address of an SNMP device | string |
| `snmp_admin_status` | query | The new admin status, either 'up' or 'down' | string |
| `snmp_port_idx` | query | The index of the SNMP device interface | string |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-4` INVALID_HOST; `-5` INVALID_ARGUMENTS; `-26` SNMP_DEVICE_INTERFACE_STATUS_CHANGE_FAILED

<a id="Pools"></a>

## Pools

### GET /lua/rest/v1/add/host/pool.lua

**Add an host pool**

**Description:** Add an host pool with members and configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-13` ADD_POOL_FAILED

### GET /lua/rest/v1/add/network/pool.lua

**Add a local network pool**

**Description:** Add a local network pool with members and configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-13` ADD_POOL_FAILED

### GET /lua/rest/v1/edit/host/pool.lua

**Edit an host pool**

**Description:** Edit an host pool with members and configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-14` EDIT_POOL_FAILED

### GET /lua/rest/v1/edit/network/pool.lua

**Edit a local network pool**

**Description:** Edit a local network pool with members and configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-14` EDIT_POOL_FAILED

### GET /lua/rest/v1/edit/host_pool/pool.lua

**Edit an host pool pool**

**Description:** Edit an host pool pool (only recipients edit is allowed)

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-14` EDIT_POOL_FAILED

### GET /lua/rest/v1/delete/host/pool.lua

**Delete an host pool**

**Description:** Delete an host pool

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-16` POOL_NOT_FOUND

### GET /lua/rest/v1/delete/network/pool.lua

**Delete a local network pool**

**Description:** Delete a local network pool

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-16` POOL_NOT_FOUND

### GET /lua/rest/v1/delete/pools.lua

**Delete all pools for any available pool type**

**Description:** Delete all pools for any available pool type

**Produces:** `application/json`

**Responses**

`0` OK

### GET /lua/rest/v1/get/host/pools.lua

**Get one or all host pools**

**Description:** Get one or all host pools

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-16` POOL_NOT_FOUND

### GET /lua/rest/v1/get/network/pools.lua

**Get one or all local network pools**

**Description:** Get one or all local network pools

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-16` POOL_NOT_FOUND

### GET /lua/rest/v1/get/pools.lua

**Get all pools of any type**

**Description:** Get all pools defined for any available pool type

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK

### GET /lua/rest/v1/recipient/pools.lua

**Get all pools of any type for a given recipient id**

**Description:** Get all pools defined for any available pool type for a given recipient id

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `recipient_id` | query | A recipient id | int16 |

**Responses**

`0` OK

### GET /lua/rest/v1/get/host/pool/members.lua

**Get all host pool members**

**Description:** Get all the members of a given host pool

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-16` POOL_NOT_FOUND

### GET /lua/rest/v1/bind/host/pool/member.lua

**Bind a member to an host pool**

**Description:** Bind a member to an host pool

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-17` BIND_POOL_MEMBER_FAILED

### GET /lua/rest/v1/get/host/pool_by_member.lua

**Get an host pool given a member**

**Description:** Get an host pool given a member

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `` |  |  |  |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS

### POST lua/rest/v1/export/pool/config.lua

**Export the pools configuration as a JSON file**

**Description:** Export the configuration of all pools and dependencies (notifications, SNMP, active monitoring, checks

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/import/pool/config.lua

**Import the pools configuration providing a JSON file**

**Description:** Import the configuration of all pools and dependencies (notifications, SNMP, active monitoring, checks

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

<a id="Notification Recipients"></a>

## Notification Recipients

### GET /lua/rest/v1/delete/recipients.lua

**Delete all defined recipients and reset them to factory-defaults**

**Description:** Delete all defined recipients and reset them to factory-defaults

**Produces:** `application/json`

**Responses**

`0` OK

<a id="Notification Endpoints"></a>

## Notification Endpoints

### GET /lua/rest/v1/delete/endpoints.lua

**Delete all defined notification endpoints and reset them to factory-defaults**

**Description:** Delete all defined notification endpoints and reset them to factory-defaults

**Produces:** `application/json`

**Responses**

`0` OK

<a id="All"></a>

## All

### GET /lua/rest/v1/get/system/stats.lua

**Get system stats**

**Description:** Get statistics of the system on top of which ntopng is running

**Produces:** `application/json`

**Responses**

`0` OK

### POST lua/rest/v1/export/all/config.lua

**Export all configurations as a JSON file**

**Description:** Export all configurations including Pools, Active Monitoring, Notifications (Endpoints and Recipients), Checks, SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/import/all/config.lua

**Import all configurations providing a JSON file**

**Description:** Import all configurations including Pools, Active Monitoring, Notifications (Endpoints and Recipients), Checks, SNMP devices

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### POST lua/rest/v1/reset/all/config.lua

**Reset all configurations**

**Description:** Reset all configurations

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v1/check/infrastructure/config.lua

**Test an infrastructure configuration**

**Description:** Uses an url and token to connect to the REST API of an ntopng in the infrastructure

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `url` | query | The URL of the ntopng in the infrastructure | string |
| `token` | query | The REST API Token for the authentication | string |

**Responses**

`0` OK; `-42` INFRASTRUCTURE_INSTANCE_ALREADY_EXISTING; `-43` INFRASTRUCTURE_INSTANCE_CHECK_FAILED; `-44` INFRASTRUCTURE_INSTANCE_CHECK_NOT_FOUND; `-45` INFRASTRUCTURE_INSTANCE_CHECK_INVALID_RESPONSE; `-46` INFRASTRUCTURE_INSTANCE_CHECK_AUTH_FAILED

<a id="Active Monitoring"></a>

## Active Monitoring

### POST lua/rest/v1/export/active_monitoring/config.lua

**Export the active monitoring configuration as a JSON file**

**Description:** Export the active monitoring configuration

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/import/active_monitoring/config.lua

**Import the active monitoring configuration providing a JSON file**

**Description:** Import the active monitoring configuration

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

<a id="Notifications"></a>

## Notifications

### POST lua/rest/v1/export/notifications/config.lua

**Export the notifications configuration as a JSON file**

**Description:** Export the configuration for endpoints and recipients

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/import/notifications/config.lua

**Import the notifications configuration providing a JSON file**

**Description:** Import the configuration for endpoints and recipients

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

<a id=""></a>

## 

### POST lua/rest/v1/export/scripts/config.lua

**Export the Checks configuration as a JSON file**

**Description:** Export the configuration for all checks

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/export/snmp/config.lua

**Export the SNMP configuration as a JSON file**

**Description:** Export the configuration for the SNMP devices

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `download` | query | Download as file (no REST envelope) | boolean |

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST lua/rest/v1/import/scripts/config.lua

**Import the Checks configuration providing a JSON file**

**Description:** Import the configuration for all checks

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT

### POST lua/rest/v1/import/snmp/config.lua

**Import the SNMP configuration providing a JSON file**

**Description:** Import the configuration for the SNMP devices

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED; `-5` INVALID_ARGUMENTS; `-27` CONFIGURATION_FILE_MISMATCH; `-28` PARTIAL_IMPORT
