---
title: "Dump API"
description: "The Dump API exposes functions to query or modify interface disk dump preferences."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Dump API {#dump-api}

The Dump API exposes functions to query or modify interface disk dump preferences.

### `interface.liveCapture(string host)` {#interface-livecapture}

Starts a live packet capture from the selected interface.

**Parameters**

- `host`: host/host@vlan to restrict capture only to the selected host. If nil, all interface traffic will be captured

**Returns**: Success, or nil in case of failure.

### `interface.dumpLiveCaptures()` {#interface-dumplivecaptures}

Dump active live captures for the specified web user

**Returns**: table containing live captures for the specified user
