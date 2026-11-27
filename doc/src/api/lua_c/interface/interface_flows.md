---
title: "Flows API"
description: "The Flows API exposes functions to query and manage active ntopng flows."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Flows API {#flows-api}

The Flows API exposes functions to query and manage active ntopng flows.

### `interface.getFlowsInfo(string host_ip=nil, table pag_options=nil)` {#interface-getflowsinfo}

Get active flows information.

**Parameters**

- `host_ip`: filter by host/host@vlan.
- `pag_options`: options for the paginator.

**Returns**: table (num_flows, flows) on success (see Flow::lua), nil otherwise.

### `interface.getFlowsStatus()` {#interface-getflowsstatus}

Get active flows status statistics

**Returns**: a table (status -> num_flows) for every status (RST, SYN, Established, FIN) on success, nil otherwise.

### `interface.getGroupedFlows(string group_col, table pag_options=nil)` {#interface-getgroupedflows}

Group active flows by a specified criteria.

**Parameters**

- `group_col`: the grouping column
- `pag_options`: options for the paginator.

**Returns**: table with grouped flows information on success, nil otherwise.

### `interface.getFlowsStats()` {#interface-getflowsstats}

Get active flows nDPI bytes count.

**Returns**: table (num_flows, protos, breeds) which map (protocol_name->bytes_count) on success, nil otherwise.

### `interface.getnDPIFlowsCount()` {#interface-getndpiflowscount}

Get the number of active flows by nDPI protocol

**Returns**: a table (protocol_name -> num_flows) on success, nil otherwise.

### `interface.getFlowKey(string cli_ip, int cli_port, string srv_ip, int srv_port, int l4_proto)` {#interface-getflowkey}

Computes the unique flow identifier.

**Parameters**

- `cli_ip`: host/host@vlan.
- `cli_port`: the client port.
- `srv_ip`: host/host@vlan.
- `srv_port`: the server port.
- `l4_proto`: l4 protocol id

**Returns**: the numeric flow key on success, nil otherwise.

### `interface.findFlowByTuple(string cli_ip, string srv_ip, int vlan, int cli_port, int srv_port, int l4_proto)` {#interface-findflowbytuple}

Get flow information by specifying the 5-tuple.

**Parameters**

- `cli_ip`: host.
- `srv_ip`: host.
- `vlan`: the VLAN.
- `cli_port`: the client port.
- `srv_port`: the server port.
- `l4_proto`: l4 protocol id

**Returns**: a table with the flow information (see Flow::lua) on success, nil otherwise.

### `interface.findFlowByKeyAndHashId(int key, int hashid)` {#interface-findflowbykeyandhashid}

Returns a single active flow information.

**Parameters**

- `key`: the flow key.
- `hashid`: the flow hash ID.

**Returns**: the flow information on success, nil otherwise.

### `interface.dropFlowTraffic(int key, int hashid)` {#interface-dropflowtraffic}

Drops an active flow traffic.

**Parameters**

- `key`: the flow key.
- `hashid`: the flow hash ID.

**Returns**: true on success, false otherwise

::: info
this is only effective when using nEdge.
:::
