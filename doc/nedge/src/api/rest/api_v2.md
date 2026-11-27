---
title: "RESTful API v2 Specification"
description: "The HTTP/HTTPS authentication should be used, for example with curl it is possible to specify username and password with"
outline: [2, 3]
lastUpdated: 2025-03-31T13:04:44+02:00
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

<a id="Interfaces"></a>

## Interfaces

### GET /lua/pro/rest/v2/get/nedge/interfaces.lua

**Get nEdge interfaces**

**Description:** Get all the network interfaces used by nEdge

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/nedge/gateways/status.lua

**Get gateways status information**

**Description:** Read information about gateways

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/nedge/physical/interface/data.lua

**Get interface information**

**Description:** Read information about an interface

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `ifid` | query | Interface identifier | integer |

**Responses**

`0` OK; `-2` INVALID_INTERFACE; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/nedge/dhcp_active_leases.lua

**Get DHCP leases**

**Description:** Read active DHCP elases

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/add/nedge/vlan/add_vlan.lua

**Add a VLAN interface**

**Description:** Add a VLAN interface

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `interface` | formData | Physical interface | string |
| `vlan_id` | formData | VLAN ID | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/delete/nedge/vlan/remove_vlan.lua

**Delete a VLAN interface**

**Description:** Remove a VLAN interface

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `delete_vlan` | formData | VLAN ID | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Users"></a>

## Users

### GET /lua/pro/rest/v2/get/nedge/users/status.lua

**Get users stats**

**Description:** Read traffic stats about users

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="Policy"></a>

## Policy

### POST /lua/pro/rest/v2/set/nedge/interface/state.lua

**Enable or disable a WAN interface**

**Description:** Set the state (enabled or disabled) of a WAN interface

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `interface` | formData | WAN interface name | string |
| `enabled` | formData | New interface enable state: 'true' or 'false' | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### GET /lua/pro/rest/v2/get/nedge/policy/default.lua

**Get default policy for inter-LAN traffic**

**Description:** Read default policy for inter-LAN traffic

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/set/nedge/policy/default.lua

**Set default policy for inter-LAN traffic**

**Description:** Set default policy for inter-LAN traffic

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `default_policy` | formData | Policy: accept or deny | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR; `-7` BAD_FORMAT

### GET /lua/pro/rest/v2/get/nedge/policy/rules.lua

**Get rules for inter-LAN traffic**

**Description:** Read all configured rules to allow/deny inter-LAN traffic

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/add/nedge/policy/rule.lua

**Add a policy for inter-LAN traffic**

**Description:** Add a new policy for inter-LAN traffic and return the ID

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `src_type` | formData | Source type: 'cidr' or 'interface' | string |
| `src_value` | formData | Source (e.g. '192.168.1.0/24' or 'eno2.11') | string |
| `dst_type` | formData | Destination type: 'cidr' or 'interface' | string |
| `dst_value` | formData | Destination (e.g. '192.168.1.0/24' or 'eno2.11') | string |
| `bidirectional` | formData | Bidirectionsl: 'true' or 'false' | string |
| `policy` | formData | Policy: 'accept' or 'deny' | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/pro/rest/v2/edit/nedge/policy/rule.lua

**Edit a policy by ID**

**Description:** Change a policy rule by ID

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `rule_id` | formData | Rule ID to edit | string |
| `new_rule_id` | formData | New Rule ID | string |
| `src_type` | formData | Source type: 'cidr' or 'interface' | string |
| `src_value` | formData | Source (e.g. '192.168.1.0/24' or 'eno2.11') | string |
| `dst_type` | formData | Destination type: 'cidr' or 'interface' | string |
| `dst_value` | formData | Destination (e.g. '192.168.1.0/24' or 'eno2.11') | string |
| `bidirectional` | formData | Bidirectionsl: 'true' or 'false' | string |
| `policy` | formData | Policy: 'accept' or 'deny' | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/delete/nedge/policy/rule.lua

**Delete a policy rule**

**Description:** Delete a policy rule by id

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `rule_id` | formData | Rule ID to delete | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

### GET /lua/pro/rest/v2/get/nedge/forwarders.lua

**Get broadcast/multicast forwarding rules**

**Description:** Read all configured broadcast/multicast forwarding rules

**Produces:** `application/json`

**Responses**

`0` OK; `-3` NOT_GRANTED

### POST /lua/pro/rest/v2/add/nedge/forwarder.lua

**Add a rule for broadcast/multicast forwarding**

**Description:** Add a new rule for broadcast/multicast forwarding

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `repeater_type` | formData | Repeater type (e.g. 'custom') | string |
| `ip` | formData | Multicast IP address | string |
| `interfaces` | formData | Trusted interfaces | string |
| `interface_details` | formData |  | string |
| `restricted_interfaces` | formData | Restricted interfaces | string |
| `restricted_interface_details` | formData |  | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/pro/rest/v2/edit/nedge/forwarder.lua

**Edit a broadcast/multicast forwarding rule**

**Description:** Edit a broadcast/multicast forwarding rules by ID

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `repeater_id` | formData | Repeater rule ID | string |
| `new_repeater_id` | formData | New repeater rule ID | string |
| `repeater_type` | formData | Repeater type (e.g. 'custom') | string |
| `ip` | formData | Multicast IP address | string |
| `interfaces` | formData | Trusted interfaces | string |
| `interface_details` | formData |  | string |
| `restricted_interfaces` | formData | Restricted interfaces | string |
| `restricted_interface_details` | formData |  | string |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS; `-6` INTERNAL_ERROR

### POST /lua/rest/v2/delete/nedge/forwarder.lua

**Delete multicast/broadcast forwarder rule**

**Description:** Delete multicast/broadcast forwarder rule by id

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `repeater_id` | formData | Repeater rule ID | string |

**Responses**

`0` OK; `-3` NOT_GRANTED

<a id="nEdge"></a>

## nEdge

### POST /lua/pro/rest/v2/set/nedge/interface/drop_host_flows.lua

**Drop all active flows for the specified host**

**Description:** Set flow verdict to drop for all active flows for the specified host

**Consumes:** `application/json`

**Produces:** `application/json`

**Parameters**

| Name | Position | Description | Type |
|---|---|---|---|
| `body` | body | JSON payload | object |

**Responses**

`0` OK; `-5` INVALID_ARGUMENTS
