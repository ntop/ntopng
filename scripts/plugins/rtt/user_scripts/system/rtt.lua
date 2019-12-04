--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local rtt_utils = require("rtt_utils")
local ts_utils = require("ts_utils_core")

-- Enable do_trace messages
local do_trace = false

local script = {
  -- This module is enabled by default
  default_enabled = true,

  -- Exclude this script in Windows
  windows_exclude = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},
}

-- #################################################################

local function pingIssuesType(value, threshold, ip)
  return({
    alert_type = alert_consts.alert_types.alert_ping_issues,
    alert_severity = alert_consts.alert_severities.warning,
    alert_granularity = alert_consts.alerts_granularities.min,
    alert_type_params = {
      value = value, threshold = threshold, ip = ip,
    }
  })
end

-- ##############################################

local function triggerRttAlert(numeric_ip, ip_label, current_value, upper_threshold)
  local entity_info = alerts_api.pingedHostEntity(ip_label)
  local type_info = pingIssuesType(current_value, upper_threshold, numeric_ip)

  return alerts_api.trigger(entity_info, type_info)
end

-- ##############################################

local function releaseRttAlert(numeric_ip, ip_label, current_value, upper_threshold)
  local entity_info = alerts_api.pingedHostEntity(ip_label)
  local type_info = pingIssuesType(current_value, upper_threshold, numeric_ip)

  return alerts_api.release(entity_info, type_info)
end

-- #################################################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
  local hosts = rtt_utils.getHosts()
  local pinged_hosts = {}
  local max_latency = {}
  local when = params.when

  if(do_trace) then
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
          if do_trace then
             print("[RTT] Could not resolve IPv4 host: ".. host_label .."\n")
          end
	  goto continue
       end
     elseif not isIPv6(host_label) and is_v6 then
	ip_address = ntop.resolveHost(host_label, false --[[IPv6 --]])

	if not ip_address then
          if do_trace then
             print("[RTT] Could not resolve IPv6 host: ".. host_label .."\n")
          end
	  goto continue
	end
     end

     if do_trace then
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

	if(do_trace) then
	   print("[RTT] Reading response for host ".. host .."\n")
	end

	if params.ts_enabled then
	   ts_utils.append("monitored_host:rtt", {ifid = getSystemInterfaceId(), host = key, millis_rtt = rtt}, when)
	end

	rtt = tonumber(rtt)
	rtt_utils.setLastRttUpdate(key, when, rtt, host)
	
	if(max_rtt and (rtt > max_rtt)) then
	  if(do_trace) then print("[TRIGGER] Host "..host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
	  triggerRttAlert(host, key, rtt, max_rtt)
	else
	  if(do_trace) then print("[OK] Host "..host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
	  releaseRttAlert(host, key, rtt, max_rtt)
	end
	
	pinged_hosts[host] = nil -- Remove key
     end
  end

  for ip,label in pairs(pinged_hosts) do
     if(do_trace) then print("[TRIGGER] Host "..ip.."/"..label.." is unreacheable\n") end
     triggerRttAlert(ip, label, 0, 0)
  end

  if(do_trace) then
     print("[RTT] Script is over\n")
  end
end

-- #################################################################

return script
