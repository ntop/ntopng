# Host Class

The `Host` class provides information about hosts.

## Constructor

### `__init__(self, ntopng_obj, ifid, ip, vlan=None)`

Constructs a new `Host` object.

- `ntopng_obj`: The ntopng handle (Ntopng instance).
- `ifid`: The interface ID (integer).
- `ip`: The host IP address (string).
- `vlan` (optional): The host VLAN ID (integer, if applicable).

## Methods

### `get_host_data(self)`

Returns all available information about a single host.

- Returns: Information about the host (object).

### `get_l7_stats(self)`

Returns statistics about Layer 7 protocols for the host.

- Returns: Layer 7 protocol statistics (object).

### `get_dscp_stats(self, direction_rcvd)`

Returns statistics about DSCP (Differentiated Services Code Point) per traffic direction for a host.

- `direction_rcvd`: The traffic direction (True for received traffic, False for sent).
- Returns: DSCP statistics (object).

### `get_active_flows_paginated(self, currentPage, perPage)`

Retrieves the paginated list of active flows for the specified interface and host.

- `currentPage`: The current page (integer).
- `perPage`: The number of results per page (integer).
- Returns: All active flows (array).

