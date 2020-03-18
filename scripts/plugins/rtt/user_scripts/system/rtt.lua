--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local rtt_utils = require("rtt_utils")
local ts_utils = require("ts_utils_core")

-- Enable do_trace messages
local do_trace = false

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  -- This module is enabled by default
  default_enabled = true,

  -- Exclude this script in Windows
  windows_exclude = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},

  gui = {
    i18n_title = "host_config.rtt_monitor",
    i18n_description = "host_config.rtt_monitor_description",
  },
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

-- Resolve the domain name into an IP if necessary
local function resolveRttHost(domain_name, is_v6)
   local ip_address = nil

   if not isIPv4(domain_name) and not is_v6 then
     ip_address = ntop.resolveHost(domain_name, true --[[IPv4 --]])

     if not ip_address then
	if do_trace then
	   print("[RTT] Could not resolve IPv4 host: ".. domain_name .."\n")
	end
     end
   elseif not isIPv6(domain_name) and is_v6 then
      ip_address = ntop.resolveHost(domain_name, false --[[IPv6 --]])

      if not ip_address then
	if do_trace then
	   print("[RTT] Could not resolve IPv6 host: ".. domain_name .."\n")
	end
      end
   else
     ip_address = domain_name
   end

  return(ip_address)
end

-- #################################################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
  local all_hosts = rtt_utils.getHosts()
  local pinged_hosts = {}
  local hosts_rtt = {}
  local resolved_hosts = {}
  local when = params.when

  if(do_trace) then
     print("[RTT] Script started\n")
  end

  if table.empty(all_hosts) then
    return
  end

  for key, host in pairs(all_hosts) do
     local domain_name = host.host

     if((host.measurement == "icmp") or (host.measurement == "icmp6")) then
       local is_v6 = (host.measurement == "icmp6")
       local ip_address = resolveRttHost(domain_name, is_v6)

       if not ip_address then
	 goto continue
       end

       if do_trace then
	 print("[RTT] Pinging "..ip_address.."/"..domain_name.."\n")
       end

       -- ICMP results are retrieved in batch (see below ntop.collectPingResults)
       ntop.pingHost(ip_address, is_v6)

       pinged_hosts[ip_address] = key
       resolved_hosts[key] = ip_address
     elseif((host.measurement == "http") or (host.measurement == "https")) then
       if do_trace then
	 print("[RTT] GET "..domain_name.."\n")
       end

       -- HTTP results are retrieved immediately
       local rv = ntop.httpGet(domain_name, nil, nil, 10 --[[ timeout ]], false --[[ don't return content ]],
	nil, false --[[ don't follow redirects ]])

       if(rv and rv.HTTP_STATS and (rv.HTTP_STATS.TOTAL_TIME > 0)) then
         local total_time = rv.HTTP_STATS.TOTAL_TIME * 1000
	 local lookup_time = (rv.HTTP_STATS.NAMELOOKUP_TIME or 0) * 1000
	 local connect_time = (rv.HTTP_STATS.APPCONNECT_TIME or 0) * 1000

	 hosts_rtt[key] = total_time
	 resolved_hosts[key] = rv.RESOLVED_IP

	 -- HTTP specific metrics
	 ts_utils.append("monitored_host:http_stats", {
	    ifid = getSystemInterfaceId(),
	    host = key,
	    lookup_ms = lookup_time,
	    connect_ms = connect_time,
	    other_ms = (total_time - lookup_time - connect_time),
	 }, when)
	end
     else
       print("[RTT] Unknown measurement: " .. host.measurement)
       goto continue
     end

     ::continue::
  end

  -- Collect possible ICMP results
  if not table.empty(pinged_hosts) then
     ntop.msleep(2000) -- wait results

     local res = ntop.collectPingResults()

     for host, rtt in pairs(res or {}) do
	local key = pinged_hosts[host]

	if(do_trace) then
	  print("[RTT] Reading ICMP response for host ".. host .."\n")
	end

	hosts_rtt[key] = tonumber(rtt)
     end
  end

  -- Parse the results
  for key, rtt in pairs(hosts_rtt) do
    local host = all_hosts[key]
    local resolved_host = resolved_hosts[key] or host.host
    local max_rtt = host.max_rtt

    if params.ts_enabled then
       ts_utils.append("monitored_host:rtt", {ifid = getSystemInterfaceId(), host = key, millis_rtt = rtt}, when)
    end

    rtt_utils.setLastRttUpdate(key, when, rtt, resolved_host)

    if(max_rtt and (rtt > max_rtt)) then
      if(do_trace) then print("[TRIGGER] Host "..resolved_host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
      triggerRttAlert(resolved_host, key, rtt, max_rtt)
    else
      if(do_trace) then print("[OK] Host "..resolved_host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
      releaseRttAlert(resolved_host, key, rtt, max_rtt)
    end
  end

  -- Find the unreachable hosts
  for key, host in pairs(all_hosts) do
     local ip = resolved_hosts[key] or host.host

     if(hosts_rtt[key] == nil) then
       if(do_trace) then print("[TRIGGER] Host "..ip.."/"..key.." is unreacheable\n") end
       triggerRttAlert(ip, key, 0, 0)
     end
  end

  if(do_trace) then
     print("[RTT] Script is over\n")
  end
end

-- #################################################################

return script
