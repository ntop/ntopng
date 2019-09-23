--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local rtt_utils = require("rtt_utils")
local format_utils = require("format_utils")
local alerts_api = require("alerts_api")

local probe = {
  name = "RTT Monitor",
  description = "Monitors the round trip time of an host",
  page_script = "rtt_stats.lua",
  page_order = 1500,
}

local debug = false

-- ##############################################

function probe.isEnabled()
  return(not ntop.isWindows())
end

-- ##############################################

function probe.entityConfig(entity_type, entity_value)
   local h_info = hostkey2hostinfo(entity_value)
   local h_ip = h_info["host"]
   local rtt_host_key = rtt_utils.host2key(h_ip, ternary(isIPv4(h_ip), "ipv4", "ipv6"), "icmp")

   res = {}
   if entity_type == "host" then
      return {url = ntop.getHttpPrefix().."/lua/system/rtt_stats.lua?rtt_host="..rtt_host_key}
   end
end

-- ##############################################

function probe.loadSchemas(ts_utils)
  local schema

  schema = ts_utils.newSchema("monitored_host:rtt", {
    metrics_type = ts_utils.metrics.gauge,
    aggregation_function = ts_utils.aggregation.max
  })
  schema:addTag("ifid")
  schema:addTag("host")
  schema:addMetric("millis_rtt")
end

-- ##############################################

function probe.getTimeseriesMenu(ts_utils)
  return {
    {schema="monitored_host:rtt",              label=i18n("graphs.num_ms_rtt")},
  }
end

-- ##############################################

function probe.triggerRttAlert(numeric_ip, ip_label, current_value, upper_threshold)
  local entity_info = alerts_api.pingedHostEntity(ip_label)
  local type_info = alerts_api.pingIssuesType(current_value, upper_threshold, numeric_ip)

  return alerts_api.trigger(entity_info, type_info)
end

-- ##############################################

function probe.releaseRttAlert(numeric_ip, ip_label, current_value, upper_threshold)
  local entity_info = alerts_api.pingedHostEntity(ip_label)
  local type_info = alerts_api.pingIssuesType(current_value, upper_threshold, numeric_ip)

  return alerts_api.release(entity_info, type_info)
end

-- ##############################################

function probe.runTask(when, ts_utils)
  local hosts = rtt_utils.getHosts()
  local pinged_hosts = {}
  local max_latency = {}

  if(debug) then
     print("[RTT] Script started\n")
  end

  if table.empty(hosts) then
    return
  end

  for key, host in pairs(hosts) do
     local host_label = host.host
     local ip_address = host_label
     local is_v6

     if host.iptype == "ipv6" then
	is_v6 = true
     else
	is_v6 = false
     end
     
     if not isIPv4(host_label) and not is_v6 then
       ip_address = ntop.resolveHost(host_label, true --[[IPv4 --]])

       if not ip_address then
          if debug then
             print("[RTT] Could not resolve IPv4 host: ".. host_label .."\n")
          end
	  goto continue
       end
     elseif not isIPv6(host_label) and is_v6 then
	ip_address = ntop.resolveHost(host_label, false --[[IPv6 --]])

	if not ip_address then
          if debug then
             print("[RTT] Could not resolve IPv6 host: ".. host_label .."\n")
          end
	  goto continue
	end
     end

     if debug then
	print("[RTT] Pinging "..ip_address.."/"..host_label.."\n")
     end

     ntop.pingHost(ip_address, is_v6)
     pinged_hosts[ip_address] = key
     max_latency[ip_address]  = host.max_rtt

     ::continue::
  end

  ntop.msleep(2000) -- wait results
  
  local res = ntop.collectPingResults()

  if(res ~= nil) then
     for host, rtt in pairs(res) do
	local max_rtt = max_latency[host]
	local key     = pinged_hosts[host]

	if(debug) then
	   print("[RTT] Reading response for host ".. host .."\n")
	end

	ts_utils.append("monitored_host:rtt", {ifid = getSystemInterfaceId(), host = key, millis_rtt = rtt}, when)

	rtt = tonumber(rtt)
	rtt_utils.setLastRttUpdate(key, when, rtt, host)
	
	if(max_rtt and (rtt > max_rtt)) then
     if(debug) then print("[TRIGGER] Host "..host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
     probe.triggerRttAlert(host, key, rtt, max_rtt)
	else
     if(debug) then print("[OK] Host "..host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
     probe.releaseRttAlert(host, key, rtt, max_rtt)
	end
	
	pinged_hosts[host] = nil -- Remove key
     end
  end
  
  for ip,label in pairs(pinged_hosts) do
     if(debug) then print("[TRIGGER] Host "..ip.."/"..label.." is unreacheable\n") end
     probe.triggerRttAlert(ip, label, 0, 0)
  end

  if(debug) then
     print("[RTT] Script is over\n")
  end
end

-- ##############################################

return probe
