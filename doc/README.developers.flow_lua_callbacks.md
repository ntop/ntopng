# Introduction


ntopng periodically visit all flows to perform operations such as counter and throughput updates, as well as the triggering of alerts. The periodicity of such visits varies:

- For packet interfaces, the default periodicity equals 5 seconds and can be configured from the preferences.
- For ZMQ interfaces, periodicity is determined using the maximum between the active (`-t`) and the idle (`-d`) timeouts received from nProbe.

# Custom Scripts Function Calls

During these periodic visits, ntopng can call certain functions found inside custom lua scripts, passing them the flows for further processing. Such functions are called at certain pre-defined events or stages of the flow lifecycle:

- Function `protocolDetected`: called after the Layer-7 application protocol has been detected
- Function `statusChanged`: called when the status of the flow has changed since the previous visit
- Function `periodicUpdate`:called every few minutes on long-lived flows
- Function `idle`: called when the flow has gone idle

Specifically, ntopng periodically iterates all the custom lua scripts and calls the function on all the scripts in which it is defined.

NOTE: flows never go idle when processing pcap files. However, function `idle` is called one time for every flow once ntopng has finished processing all the packets in the pcap file. 

## protocolDetected

For packet interfaces, ntopng detects the Layer-7 application protocol of a flow within its first 12 packets. In case of ZMQ interfaces, the protocol of a flow is marked as detected right after the flow has been received. The first time the periodic visit steps on the flow after its protocol has been detected, it will call `protocolDetected`.

## statusChanged

Every flow has a bitmap of statuses associated. A new flow starts with a clear bitmap. This bitmap is then modified during the lifecycle of the flow to set new statuses (e.g., when retransmissions are detected, or when the flow is marked as blacklisted). Every time a periodic visit on the flow detect the statuses bitmap has changed since the previous visit, it will call `statusChanged`. Statuses can change both for packet as well as for ZMQ interfaces.

## periodicUpdate

Periodic visits call function `periodicUpdate` on long-lived flows every few minutes. This function is called at intervals equal to 5 times the maximum flow idleness. The maximum flow idleness:

- Defaults to 1 minute for packet interfaces and it can be changed from the preferences
- Is determined using the active (`-t`) timeout for ZMQ interfaces

## idle

When a flow becomes idle, after an amount of time which depends on the maximum flow idleness as discussed in `periodicUpdate`, the periodic visit will step on it the last time and will call `idle`, both for packet as well as for ZMQ interfaces.

## Custom Scripts

ntopng reads custom scripts under `scripts/callbacks/interface/alerts/flow/`. Placing a `.lua` file there will cause ntopng to load it.

The skeleton of a custom can be the following:

```
local check_module = {
   key = "a_custom_module_name",

   gui = {
      i18n_title = "My Custom Script",
      i18n_description = "This script performs certain custom operations",
      input_builder = alerts_api.flow_checkbox_input_builder,
   }
}


-- #################################################################

function check_module.setup()
  return true
end

-- #################################################################

function check_module.protocolDetected()
  -- Custom actions
end

-- #################################################################

return check_module
```

The `key` is a unique identifier for the script. The `gui` part contains a `title` and a `description` which are shown in the ntopng interface custom scripts page, and an `input_builder` which currently supports only a checkbox to enable or disable the script from the gui. Localized i18n strings can be used both for the `title` and the `description`.

Function `setup()` must always be present and it must return true if the module has to be enabled or false if the module has to be disabled.

Then, the script can define zero or more of the functions highlighted above, namely: `protocolDetected`, `statusChanged`, `periodicUpdate` and `idle`. Defining a function will cause ntopng to call it, passing a table generated out of the `Flow::lua()` call as the first argument.

A global `flow` table is available in each of the functions above. Such table gives direct access to flow information through a series of callable functions. Those function are documented in the next section.

### Example

Let's see how to create a custom script which checks flow client and server countries, and perform certain actions when either the client or the server is found to be from China. As this script should be executed as early as possible in the lifecycle of a flow, `protocolDetected` function is used to do the check on the countries and to perform the actions.

The script can be written to file `suspicious_countries.lua`. Although any file name is valid, it is recommended to pick a name which is somehow indicative of the actual script actions. To make sure ntopng will execute it, `suspicious_countries.lua` has to be placed under directory `scripts/callbacks/interface/flow/`.

The minimum contents of such script are the following:

```

--
-- (C) 2019 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local do_trace = false

-- #################################################################

local check_module = {
   key = "suspicious_countries",

   gui = {
      i18n_title = "Suspicious Countries",
      i18n_description = "Trigger an alert when at least one among the client and server is from a suspicious country",
      input_builder = alerts_api.flow_checkbox_input_builder,
   }
}

-- #################################################################

function check_module.setup()
   return true
end

-- #################################################################

function check_module.protocolDetected()
   local cli_geo = flow.getClientGeolocation()
   local srv_geo = flow.getServerGeolocation()

   if cli_geo["cli.country"] == "CN" or srv_geo["srv.country"] == "CN" then
      tprint("From China") -- this will print the message "From China" to the standard output
      -- Execute custom actions:
      -- Raise an alert...
      -- Increase the flow score...
   end
end

-- #################################################################

return check_module

```

Let's focus on the `check_module.protocolDetected`, which is the function ntopng will execute, as the other parts of the script have already been discussed above.

The first thing to do in `check_module.protocolDetected` is to access global table `flow` to fetch client and server countries. Countries can be fetched with `getClientGeolocation` and `getServerGeolocation`, both documented in the next section. Those functions return a table with multiple keys containing geolocation information. Countries are contained in keys `cli.country` and `srv.country`, so for the script it suffices to check table values for such keys to determine whether the client or the server is from China. If any of the two peers is from China (country code `CN`), then actions contained in the if branch will be executed. The script just print a message to the standard output but other actions such as raising an alert or increasing the flow score can be done in this branch as well.


# Obtaining Flow Information From Custom Scripts

The number of flows on which custom scripts can be run against can be potentially very high, so it is fundamental to keep the computational cost of these scripts as low as possible. Experiments run highlighted that calling the `Flow::lua` for every flow was prohibitive. To reduce the computational cost but still be able to fetch flow information, we have factorized `Flow::lua` into several smaller functions and have exposed them to lua individually.

## Currently Exposed Functions

All exposed functions return a table with one or more keys. Keys depend on the function called. An always-updated list is  available in method `Flow::initLuaMethodIdToName`. The list of functions which have been currently exposed is the following:

### getStatus

`getStatus` returns the status bitmap of the flow, a boolean indicating if the flow is idle, and another boolean indicating if the flow is alerted

Returned table example:
```
 table
flow.status number 0
flow.idle boolean false
status_map number 1
```

### getProtocols

`getProtocols` returns the Layer-4 and the Layer-7 protocols, along with the Layer-7 protocol category and breed.

Returned table example:
```
 table
proto.ndpi_id number 7
proto.ndpi_breed string Acceptable
proto.l4 string TCP
proto.ndpi_cat string Web
proto.ndpi_cat_id number 5
proto.ndpi string HTTP
```

### getBytes

`getBytes` returns the total number of bytes and goodput bytes, counted as sum in both directions, that is, client to server and server to client.

Returned table example:
```
 table
bytes.last number 2695
goodput_bytes.last number 1949
bytes number 2695
goodput_bytes number 1949
```

### getClient2ServerTraffic

`getClient2ServerTraffic` returns bytes, packets and packet length distributions for the client to server direction.

Returned table example:
```
 table
cli2srv.goodput_bytes number 448
cli2srv.pkt_len.min number 66
cli2srv.pkt_len.stddev number 166
cli2srv.last number 856
cli2srv.pkt_len.avg number 142
cli2srv.packets number 6
cli2srv.fragments number 0
cli2srv.bytes number 856
cli2srv.pkt_len.max number 514
```

### getServer2ClientTraffic

`getServer2ClientTraffic` returns bytes, packets and packet length distributions for the client server to client direction.

Returned table example:
```
 table
srv2cli.pkt_len.stddev number 439
srv2cli.goodput_bytes number 1504
srv2cli.fragments number 0
srv2cli.packets number 5
srv2cli.pkt_len.min number 66
srv2cli.last number 1842
srv2cli.pkt_len.avg number 368
srv2cli.bytes number 1842
srv2cli.pkt_len.max number 1201
```

### getClient2ServerIAT

`getClient2ServerIAT` returns interarrival time statistics for the client to server direction of the flow. Returned statistics have minimum, average, maximum and standard deviation.

Returned table example:
```
 table
interarrival.cli2srv table
interarrival.cli2srv.min number 0
interarrival.cli2srv.avg number 49.652172088623
interarrival.cli2srv.max number 195
interarrival.cli2srv.stddev number 35.158782958984

```

### getServer2ClientIAT

`getServer2ClientIAT` returns interarrival time statistics for the server to client direction of the flow. Returned statistics have minimum, average, maximum and standard deviation.

Returned table example:
```
 table
interarrival.srv2cli table
interarrival.srv2cli.min number 0
interarrival.srv2cli.avg number 80.307693481445
interarrival.srv2cli.max number 298
interarrival.srv2cli.stddev number 76.409202575684
```

### getPackets

`getPackets` returns the total number of packets, counted as sum in both directions, that is, client to server and server to client.

Returned table example:
```
 table
packets number 12
packets.last number 12
```

### getTime

`getTime` returns flow duration, along with the first and last seen, expressed as unix epochs.

Returned table example:
```
 table
duration number 1
seen.first number 1569859250
seen.last number 1569859251
```

### getClientIp
`getClientIp` returns the ip address of the client, along with the ip address key

Returned table example:
```
 table
cli.key number 3232236253
cli.ip string 192.168.2.221
```

### getServerIp

`getServerIp` returns the ip address of the server, along with the ip address key

Returned table example:
```
 table
srv.key number 2412515162
srv.ip string 143.204.15.90
```

### getClientInfo

`getClientInfo` returns detailed information on the flow client. Information include network and host pool ids, whether this host is private, blacklisted, local or a system host, its mac address, and a visual name.

Returned table example:
```
 table
cli.network_id number 1
cli.host string ubuntu
cli.private boolean true
cli.source_id number 0
cli.pool_id number 3
cli.blacklisted boolean false
cli.systemhost boolean false
cli.mac string 0C:C4:7A:CC:C4:4A
```

### getServerInfo

`getServerInfo` is identical to `getClientInfo` except that it returns values for the server of the flow.

Returned table example:
```
 table
srv.blacklisted boolean false
srv.source_id number 0
srv.private boolean true
srv.mac string 00:25:90:D4:CC:F9
srv.pool_id number 2
srv.network_id number 1
srv.host string devel
srv.systemhost boolean true
```

### getSSLInfo

`getSSLInfo` returns SSL information, including the dissected certificate name, JA3 fingerprints, ciphers and version. An empty table is returned for non-SSL flows.

Returned table example:
```
 table
protos.ssl.server_certificate string www.lastampa.it
protos.ssl.ja3.client_hash string 4e69e4e5627c5e4c2846ba3e64d23fb9
protos.ssl.ja3.server_unsafe_cipher string safe
protos.ssl.ja3.server_hash string 76cc3e2d3028143b23ec18e27dbd7ca9
protos.ssl_version number 771
protos.ssl.ja3.server_cipher number 49199
protos.ssl.certificate string www.lastampa.it
```

### getSSHInfo

`getSSHInfo` returns SSH information, including the HASSH hashes and the signatures of client and server. An empty table is returned for non-SSH flows.

Returned table example:
```
protos.ssh.hassh.server_hash string D43D91BC39D5AAED819AD9F6B57B7348
protos.ssh.server_signature string SSH-2.0-OpenSSH_7.2p2 Ubuntu-4ubuntu2.8
protos.ssh.hassh.client_hash string 68E0BA85E1A818F7C49EA3F4B849BD15
protos.ssh.client_signature string SSH-2.0-OpenSSH_7.2p2 Ubuntu-4ubuntu2.8
```

### getHTTPInfo

`getHTTPInfo` returns HTTP information, including the server name and the last url, last method and last return code seen. An empty table is returned for non-HTTP flows.

Returned table example:
```
protos.http.server_name string devel
protos.http.last_url string devel/lua/get_flow_data.lua?flow_key=2169509007&_=1569859119920
protos.http.last_return_code number 200
protos.http.last_method string GET
```

### getDNSInfo

`getDNSInfo` returns DNS information, including the last query sent, the query type and the return code. An empty table is returned for non-DNS flows. 

Returned table example:
```
protos.dns.last_query string www.repubblica.it
protos.dns.last_return_code number 0
protos.dns.last_query_type number 0
```

### getICMPInfo

`getICMPInfo` returns the type and code for ICMP flows. If the ICMP involves an unreachable messages, reachability information is added as well. An empty table is returned for non-ICMP flows.

Returned table example:
```
 table
icmp table
icmp.code number 3
icmp.type number 3
icmp.unreach table
icmp.unreach.dst_port number 6343
icmp.unreach.dst_ip string 192.168.2.225
icmp.unreach.src_ip string 192.168.2.222
icmp.unreach.protocol number 17
icmp.unreach.src_port number 45099
```

### getTCPInfo

`getTCPInfo` returns TCP information for TCP flows. Information include the sequence numbers analysis (retransmissions, out-of-order, lost and keepalive packets), latencies and status. An empty table is returned for non-TCP flows.

Returned table example:
```
 table
tcp_established boolean false
srv2cli.tcp_flags number 24
cli2srv.keep_alive number 0
srv2cli.keep_alive number 0
tcp.appl_latency number 1.8630000352859
srv2cli.retransmissions number 0
tcp_closed boolean false
tcp.nw_latency.client number 0.0
cli2srv.tcp_flags number 24
tcp.max_thpt.srv2cli number 0.0
tcp.max_thpt.cli2srv number 0.0
srv2cli.lost number 0
srv2cli.out_of_order number 0
tcp_connecting boolean false
cli2srv.out_of_order number 0
tcp_reset boolean false
tcp.nw_latency.server number 0.0
cli2srv.lost number 0
cli2srv.retransmissions number 0
tcp.seq_problems boolean false
```

### getClientPort

`getClientPort` returns the port used by the client of the flow.


Returned table example:
```
 table
cli.port number 52504
```


### getServerPort

`getServerPort` returns the port used by the server of the flow.


Returned table example:
```
 table
srv.port number 3000
```

### getClientGeolocation

`getClientGeolocation` returns latitude, longitude, city and country of the client. When geolocation information is not available (e.g., for private ip addresses) empty strings and zero coordinates are returned.

Returned table example:
```
 table
cli.latitude number 0.0
cli.city string
cli.longitude number 0.0
cli.country string
```


### getServerGeolocation

`getServerGeolocation` returns latitude, longitude, city and country of the server. When geolocation information is not available (e.g., for private ip addresses) empty strings and zero coordinates are returned.

Returned table example:
```
 table
srv.latitude number 0.0
srv.city string
srv.longitude number 0.0
srv.country string
```


## Exposing a new function

To expose a new function so that it can be called from a custom lua script, the following steps are necessary.

First, add a new entry to the enum `FlowLuaMethod` in `ntop_typedefs.h`. Then, add a new mapping between the new enum entry and a string in `Flow::luaMethodNamesToIds`. The string added here will be the function name available from lua. Finally, add a new case to the `Flow::lua(lua_State* vm, FlowLuaMethod flm)` switch to call the right lua function.

