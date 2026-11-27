---
title: "Misc API"
description: "Miscellaneous interface functions. Misc API in the ntopng User's Guide."
outline: [2, 3]
lastUpdated: 2018-06-15T15:52:05+02:00
---
# Misc API {#misc-api}

Miscellaneous interface functions.

### `interface.getIfNames()` {#interface-getifnames}

Get the available ntopng network interfaces.

**Returns**: a table containing (ifid -> ifname) mappings.

### `interface.getFirstInterfaceId()` {#interface-getfirstinterfaceid}

Get the first available interface ID.

**Returns**: the first interface ID.

### `interface.getId()` {#interface-getid}

Get the currently selected interface ID.

**Returns**: the current interface ID.

### `interface.select(string ifname)` {#interface-select}

Set the *active interface* by using the interface name.

**Parameters**

- `ifname`: the interface name.

### `interface.hasVLANs()` {#interface-hasvlans}

Check if the network interface has seen VLAN traffic.

**Returns**: true if the interface has VLANs, false otherwise.

### `interface.hasEBPF()` {#interface-hasebpf}

Check if the network interface is capturing eBPF events.

**Parameters**

- `true`: if the interface has eBPF, false otherwise.

### `interface.getActiveFlowsStats(string host_ip=nil, int vlan_id=nil)` {#interface-getactiveflowsstats}

Get statistics including nDPI protocol information of the network interface/a specific host.

**Parameters**

- `host_ip`: filter by a specific host/host@vlan
- `vlan_id`: specify the host_ip filter vlan separately

**Returns**: table with stats on success, nil otherwise.

### `interface.getMaxIfSpeed(string ifname)` {#interface-getmaxifspeed}

Get the interface maximum speed.

**Parameters**

- `ifname`: the interface name.

**Returns**: the interface maximum speed on success, nil otherwise.

### `interface.resetCounters(bool only_drops=true)` {#interface-resetcounters}

Reset interface packets counters.

**Parameters**

- `only_drops`: if true, only reset the packet drops counter

### `interface.resetStats()` {#interface-resetstats}

Reset all the hosts and L2 devices stats (e.g. traffic and application data).

::: info
this will also reset the stats of the inactive hosts.
:::

### `interface.getEndpoint()` {#interface-getendpoint}

Get the name of the remote probe when connected via ZMQ.

**Returns**: endpoint name on success, nil otherwise.

### `interface.isPacketInterface()` {#interface-ispacketinterface}

Check if the interface captures raw packets.

**Returns**: true if the interface is a packet interface, false otherwise.

::: info
ZMQ interfaces, for example, are not packet interfaces but flow interfaces.
:::

### `interface.isDiscoverableInterface()` {#interface-isdiscoverableinterface}

Check if the network interface can be used to perform network discovery.

**Returns**: true if the interface is discoverable, false otherwise.

### `interface.isBridgeInterface()` {#interface-isbridgeinterface}

Check if current interface is an nEdge bridge interface.

**Returns**: true if the interface is a bridge interface, false otherwise.

### `interface.isPcapDumpInterface()` {#interface-ispcapdumpinterface}

Check if the network interface is a PcapInterface.

**Returns**: true if the interface is a PcapInterface, false otherwise.

### `interface.isView()` {#interface-isview}

Check if the network interface is a ViewInterface.

**Returns**: true if the interface is a ViewInterface, false otherwise.

### `interface.isViewed()` {#interface-isviewed}

Check if the network interface is viewed by a ViewInterface.

**Returns**: true if the interface is viewed by a ViewInterface, false otherwise.

### `interface.viewedBy()` {#interface-viewedby}

Get the interface ID of the ViewInterface above the current viewed interface.

**Returns**: the ViewInterface interface ID on success, nil otherwise.

### `interface.isLoopback()` {#interface-isloopback}

Get the interface ID of the ViewInterface is a loopback interface.

**Returns**: true if the interface is a loopback, false otherwise.

### `interface.isRunning()` {#interface-isrunning}

Check if the network interface has started capturing packets.

**Returns**: true if the interface is running, false otherwise.

### `interface.isIdle()` {#interface-isidle}

Check if the network interface has been temporary paused.

**Returns**: true if the interface is paused, false otherwise.

### `interface.setInterfaceIdleState(bool state)` {#interface-setinterfaceidlestate}

Temporary pause or unpause a network interface.

**Parameters**

- `state`: if true, the interface will be paused, otherwise resumed.

### `interface.getStats()` {#interface-getstats}

Get many information about the interface traffic and status.

**Returns**: table with interface stats (see NetworkInterface::lua) on success, nil otherwise.

### `interface.getNetworksStats()` {#interface-getnetworksstats}

Get local network stats.

**Returns**: table (network_name -> network_stats) on success (see NetworkStats::lua), nil otherwise.

### `interface.getNetworkStats(int network_id)` {#interface-getnetworkstats}

Get a specific local network stats.

**Parameters**

- `network_id`: the numeric ID of the network.

**Returns**: the network stats on success (see NetworkStats::lua), nil otherwise.

### `interface.getASesInfo(table pag_options=nil)` {#interface-getasesinfo}

Get active autonomous systems information.

**Parameters**

- `pag_options`: options for the paginator.

**Returns**: table (numASes, ASes) on success (see AutonomousSystem::lua), nil otherwise.

### `interface.getASInfo(int asn)` {#interface-getasinfo}

Get information about a specifc Autonomous System.

**Parameters**

- `asn`: the AS number.

**Returns**: AS information on success (see AutonomousSystem::lua), nil otherwise.

### `interface.getCountriesInfo(table pag_options=nil)` {#interface-getcountriesinfo}

Get active countries information.

**Parameters**

- `pag_options`: options for the paginator.

**Returns**: table (numCountries, Countries) on success (see Country::lua), nil otherwise.

### `interface.getVLANsList()` {#interface-getvlanslist}

Get active VLAN information.

**Returns**: table (numVLANs, VLANs) on success (see VLAN::lua), nil otherwise.

### `interface.getVLANInfo(int vlan_id)` {#interface-getvlaninfo}

Get a specific VLAN information.

**Parameters**

- `vlan_id`: the VLAN id to query.

**Returns**: VLAN information on success (see VLAN::lua), nil otherwise.

### `interface.getHostPoolsInfo()` {#interface-gethostpoolsinfo}

Get host pools information, like the number of members in the pool.

**Returns**: host pools information on success, nil otherwise.

### `interface.resetPoolsQuotas()` {#interface-resetpoolsquotas}

Reset the host pools traffic accounted in quotas (nEdge only).

### `interface.getSFlowDevices()` {#interface-getsflowdevices}

Returns a list of active sFlow probes.

**Returns**: table (device_ip -> device_ip_numeric) on success, nil otherwise.

### `interface.getSFlowDeviceInfo(string device_ip)` {#interface-getsflowdeviceinfo}

Returns information about a specific sFlow probe interfaces.

**Parameters**

- `device_ip`: the sFlow probe IP.

**Returns**: table (if_idx -> if_information) on success, nil otherwise.

### `interface.captureToPcap(int duration, string bpf_filter)` {#interface-capturetopcap}

Captures a 'duration' long pcap file. The capture is performed in background.

**Parameters**

- `duration`: The pcap duration (in seconds)
- `bpf_filter`: An optional BPF filtering expression

**Returns**: The path of the pcap file, nil otherwise.

### `interface.isCaptureRunning()` {#interface-iscapturerunning}

Checks if there is a pending captureToPcap() in progress.

**Returns**: True is there is an ongoing capture, false otherwise.

### `interface.stopRunningCapture()` {#interface-stoprunningcapture}

Stops a running capture.

### `interface.getPodsStats()` {#interface-getpodsstats}

Get information about the active PODs (eBPF only).

**Returns**: a table with active PODs (see ContainerStats::lua).

### `interface.getContainersStats(string pod_filter = nil)` {#interface-getcontainersstats}

Get information about the active Containers (eBPF only).

**Parameters**

- `pod_filter`: a filter to only show containers for the given POD

**Returns**: a table with active containers (see ContainerStats::lua).
