# Interface Class

The `Interface` class provides information about a network interface.

## Constructor

### `__init__(self, ntopng_obj, ifid)`

Constructs a new `Interface` object.

- `ntopng_obj`: The ntopng handle (Ntopng instance).
- `ifid`: The interface ID (integer).

## Methods

### `get_data(self)`

Returns information about a network interface.

- Returns: Information about the interface (object).

### `get_broadcast_domains(self)`

Returns information about broadcast domains on an interface.

- Returns: Information about broadcast domains (object).

### `get_address(self)`

Returns the interface IP address(es).

- Returns: The interface address(es) (array).

### `get_l7_stats(self, max_num_results)`

Returns statistics about Layer 7 protocols seen on an interface.

- `max_num_results`: The maximum number of results to limit the output (integer).
- Returns: Layer 7 protocol statistics (object).

### `get_dscp_stats(self)`

Returns statistics about DSCP (Differentiated Services Code Point).

- Returns: DSCP statistics (object).

### `get_host(self, ip, vlan=None)`

Returns a `Host` instance.

- `ip`: The host IP address (string).
- `vlan` (optional): The host VLAN ID (integer, if applicable).
- Returns: The host instance (`ntopng.Host`).

### `get_active_hosts(self)`

Retrieves the list of active hosts for the specified interface.

- Returns: All active hosts (array).

### `get_active_hosts_paginated(self, currentPage, perPage)`

Retrieves the paginated list of active hosts for the specified interface.

- `currentPage`: The current page (integer).
- `perPage`: The number of results per page (integer).
- Returns: All active hosts (array).

### `get_top_local_talkers(self)`

Returns the top local hosts generating more traffic on the interface.

- Returns: The top local hosts (array).

### `get_top_remote_talkers(self)`

Returns the top remote hosts generating more traffic on the interface.

- Returns: The top remote hosts (array).

### `get_active_flows_paginated(self, currentPage, perPage)`

Retrieves the paginated list of active flows for the specified interface.

- `currentPage`: The current page (integer).
- `perPage`: The number of results per page (integer).
- Returns: All active flows (array).

### `get_active_l4_proto_flow_counters(self)`

Returns statistics about active flows per Layer 4 protocol on the interface.

- Returns: Layer 4 protocol flows statistics (object).

### `get_active_l7_proto_flow_counters(self)`

Returns statistics about active flows per Layer 7 protocol on the interface.

- Returns: Layer 7 protocol flows statistics (object).

### `get_historical(self)`

Returns a `Historical` handle for the interface.

- Returns: The historical handle (`ntopng.Historical`).
