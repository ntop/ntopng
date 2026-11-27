---
title: "MACs API"
description: "The MACs API exposes functions to query and manage ntopng L2 devices."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# MACs API {#macs-api}

The MACs API exposes functions to query and manage ntopng L2 devices.

### `interface.getMacsInfo(string sortColumn="column_mac", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, bool sourceMacsOnly=false, string manufacturer=nil, int pool_filter=nil, int devtype_filter=nil, string location_filter=nil)` {#interface-getmacsinfo}

Retrieve active L2 devices information.

**Parameters**

- `sortColumn`: column to use for sorting.
- `maxHits`: maximum number of returned items.
- `toSkip`: number of initial items to skip after sorting.
- `a2zSortOrder`: if true, enable ascending sort order, otherwise order is descending.
- `sourceMacsOnly`: if true, only sender devices will be returned.
- `manufacturer`: filter by device manufacturer.
- `pool_filter`: filter by host pool ID.
- `devtype_filter`: filter by device type.
- `location_filter`: filter by device location, "lan" or "wan".

**Returns**: a table (numMacs, nextSlot, macs) on success, nil otherwise.

::: info
it's better to use the more efficient helper `callback_utils.getDevicesIterator` for generic devices iteration.
:::

### `interface.getMacInfo(string mac)` {#interface-getmacinfo}

Retrieve information about a specific L2 device.

**Parameters**

- `mac`: the mac to query information for.

**Returns**: device information on success, nil otherwise.

### `interface.getMacHosts(string mac)` {#interface-getmachosts}

Get the L2 hosts which have the specified MAC address.

**Parameters**

- `mac`: the mac.

**Returns**: a table containing the matching hosts.

### `interface.getMacManufacturers(int maxHits=32768, bool sourceMacsOnly=false, int devtype_filter=nil, string location_filter=nil)` {#interface-getmacmanufacturers}

Get a list of MAC manufacturers from active devices.

**Parameters**

- `maxHits`: maximum number of returned items.
- `sourceMacsOnly`: if true, only sender devices will be returned.
- `devtype_filter`: filter by device type.
- `location_filter`: filter by device location, "lan" or "wan".

**Returns**: table (manufacturer -> num_active_devices) on success, nil otherwise.

### `interface.setMacOperatingSystem(string mac, int os_id)` {#interface-setmacoperatingsystem}

Set L2 device operating system.

**Parameters**

- `mac`: device MAC address
- `os_id`: the operating system id to set.

### `interface.getMacDeviceTypes(int maxHits=32768, bool sourceMacsOnly=false, string manufacturer=nil, string location_filter=nil)` {#interface-getmacdevicetypes}

Get a list of device types from active devices.

**Parameters**

- `maxHits`: maximum number of returned items.
- `sourceMacsOnly`: if true, only sender devices will be return
- `manufacturer`: filter by device manufacturer.ed.
- `location_filter`: filter by device location, "lan" or "wan".

**Returns**: table (device_type -> num_active_devices) on success, nil otherwise.

### `interface.findMacPool(string mac)` {#interface-findmacpool}

Get the pool of the specified L2 device. This also works for inactive devices.

**Parameters**

- `mac`: L2 device MAC address.

**Returns**: the device pool id on success, nil otherwise.

::: info
nil is also returned for devices which do not belong to any pool.
:::

### `interface.resetMacStats(string mac)` {#interface-resetmacstats}

Reset the stats (e.g. traffic and application data) for the given device.

**Parameters**

- `mac`: L2 device MAC address.

**Returns**: true if the reset request was successful, false otherwise.

::: info
The device must be active in order to reset it. See also interface.resetStats
:::

### `interface.deleteMacData(string mac)` {#interface-deletemacdata}

Delete all the data stored for the given host.

**Parameters**

- `mac`: L2 device MAC address.

**Returns**: true if the delete request was successful, false otherwise.
