---
title: "Hosts API"
description: "The Hosts API exposes functions to query and manage active ntopng hosts."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Hosts API {#hosts-api}

The Hosts API exposes functions to query and manage active ntopng hosts.

### `interface.getHostsInfo(bool show_details=true, string sortColumn="column_ip", int maxHits=32768, int toSkip=0, bool a2zSortOrder=true, string country=nil, string os_filter=nil, int vlan_filter=nil, int asn_filter=nil, int network_filter=nil, string mac_filter=nil, int pool_filter=nil, int ipver_filter=nil, int proto_filter=nil, int traffic_type_filter=nil, bool filtered_hosts=false, bool blacklisted_hosts=false, bool hide_top_hidden=false, bool anomalousOnly=false, bool dhcpOnly=false, string cidr_filter=nil)` {#interface-gethostsinfo}

Get active hosts information.

**Parameters**

- `show_details`: enable extended information.
- `sortColumn`: column to use for sorting.
- `maxHits`: maximum number of returned items.
- `toSkip`: number of initial items to skip after sorting.
- `a2zSortOrder`: if true, enable ascending sort order, otherwise order is descending.
- `country`: filter hosts by country code.
- `os_filter`: filter hosts by os code.
- `vlan_filter`: filter hosts by vlan ID.
- `asn_filter`: filter hosts by ASN filter.
- `network_filter`: filter hosts by local network id.
- `mac_filter`: filter hosts by MAC address.
- `pool_filter`: filter hosts by host pool ID.
- `ipver_filter`: filter hosts by IP version, must be 4 or 6.
- `proto_filter`: filter hosts by nDPI protocol ID.
- `traffic_type_filter`: used to filter one/bidirectional flows
- `filtered_hosts`: if true, only return hosts with blocked flows.
- `blacklisted_hosts`: if true, only return blacklisted hosts.
- `hide_top_hidden`: if true, avoid returning hosts marked as "top hidden".
- `anomalousOnly`: if true, only return hosts with anomalies (beta feature).
- `dhcpOnly`: if true, only return hosts for which DHCP traffic was seen.
- `cidr_filter`: filter the hosts to return by using a network CIDR.

**Returns**: a table (numHosts, nextSlot, hosts) where hosts is a table (hostkey -> hostinfo) on success, nil on error.

::: info
it's better to use the more efficient helper `callback_utils.foreachHost` for generic hosts iteration.
:::

### `interface.getLocalHostsInfo(...)` {#interface-getlocalhostsinfo}

Get active local hosts information. See `getHostsInfo` for parameters description.

::: info
it's better to use the more efficient helper `callback_utils.foreachLocalHost` for generic hosts iteration.
:::

### `interface.getRemoteHostsInfo(...)` {#interface-getremotehostsinfo}

Get active remote hosts information. See `getHostsInfo` for parameters description.

### `interface.getBroadcastDomainHostsInfo(...)` {#interface-getbroadcastdomainhostsinfo}

Get active hosts information for hosts which are in the broadcast domain. See `getHostsInfo` for parameters description.

### `interface.getGroupedHosts(bool show_details=true, string groupBy="column_ip", string country=nil, string os_filter=nil, int vlan_filter=nil, int asn_filter=nil, int network_filter=nil, int pool_filter=nil, int ipver_filter=nil)` {#interface-getgroupedhosts}

Group active hosts by a specific criteria.

**Parameters**

- `show_details`: enable extended information.
- `groupBy`: the group criteria.
- `country`: filter hosts by country code.
- `os_filter`: filter hosts by os code.
- `vlan_filter`: filter hosts by vlan ID.
- `asn_filter`: filter hosts by ASN filter.
- `network_filter`: filter hosts by local network id.
- `pool_filter`: filter hosts by host pool ID.
- `ipver_filter`: filter hosts by IP version, must be 4 or 6.

**Returns**: table with grouped host information on success, nil otherwise.

### `interface.getHostInfo(string host_ip, int vlan_id=nil)` {#interface-gethostinfo}

Get host information.

**Parameters**

- `host_ip`: host/host@vlan.
- `vlan_id`: specify the host_ip vlan separately.

**Returns**: table with host information on success, nil otherwise.

### `interface.getHostCountry(string host_ip)` {#interface-gethostcountry}

Get host country.

**Parameters**

- `host_ip`: host/host@vlan.

**Returns**: the host country code on success, nil otherwise.

### `interface.findHost(string query)` {#interface-findhost}

Search hosts by name, ip or other information.

**Parameters**

- `query`: the string to use.

**Returns**: the found hosts information on success, nil otherwise.

### `interface.findHostByMac(string mac)` {#interface-findhostbymac}

Search hosts by MAC address.

**Parameters**

- `mac`: the mac address filter.

**Returns**: the found hosts information on success, nil otherwise.

### `interface.resetHostStats(string host_ip)` {#interface-resethoststats}

Reset the stats (e.g. traffic and application data) for the given host.

**Parameters**

- `host_ip`: host/host@vlan.

**Returns**: true if the reset request was successful, false otherwise.

::: info
The host must be active in order to reset it. See also interface.resetStats
:::

### `interface.deleteHostData(string host_ip)` {#interface-deletehostdata}

Delete all the data stored for the given host.

**Parameters**

- `host_ip`: host/host@vlan.

**Returns**: true if the delete request was successful, false otherwise.

### `interface.setHostOperatingSystem(string host_ip, int os_id)` {#interface-sethostoperatingsystem}

Set the operating system ID of an host

**Parameters**

- `host_ip`: host/host@vlan.
- `os_id`: the operating system ID.

### `interface.getNumLocalHosts()` {#interface-getnumlocalhosts}

Get the number of active local hosts.

**Returns**: the local hosts number.

### `interface.listHTTPhosts()` {#interface-listhttphosts}

Lists all the detected HTTP hosts

**Returns**: a table containing the HTTP hosts information (see HTTPstats::luaVirtualHosts)

### `interface.mdnsResolveName(string host_ip)` {#interface-mdnsresolvename}

Try to resolve an host name via MDNS.

**Parameters**

- `host_ip`: the host to resolve

**Returns**: the resolved host name on success, an empty otherwise.
