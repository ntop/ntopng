--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local rtt_utils = require("rtt_utils")
local format_utils = require("format_utils")
require "alert_utils"

local probe = {
  name = "RTT Monitor",
  description = "Monitors the round trip time of an host",
  page_script = "rtt_stats.lua",
  page_order = 1500,
}

local debug = false

-- no need to add the ifid in the ALERT_RAISED_KEY as
-- rtt alerts are only for the system interface
local ALERT_RAISED_KEY = "ntopng.cache.rtt.alert_raised"

-- ##############################################

local function formatAlertMessage(rtt_value, maximum_rtt, ip_label, numeric_ip)
   local msg
   -- example of an ip label:
   -- google-public-dns-b.google.com@ipv4@icmp/216.239.38.120
   local ip_label = ip_label:split("@")[1]

   if numeric_ip and numeric_ip ~= ip_label then
      numeric_ip = string.format("[%s]", numeric_ip)
   else
      numeric_ip = ""
   end

   if(rtt_value == 0) then -- host unreachable
      msg = i18n("alert_messages.ping_host_unreachable",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip})
   else -- host too slow
      msg = i18n("alert_messages.ping_rtt_too_slow",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip,
		  rtt_value = format_utils.round(rtt_value, 2),
		  maximum_rtt = maximum_rtt})
   end

   return msg
end

-- ##############################################

local function engageReleaseRTTAlert(engage, ip_label, numeric_ip, current_value, upper_threshold)
   -- we can safely use the "min" alert engine as this rtt.lua
   -- is executed by system every minute 
   local ALERT_ENGINE = alertEngine("min")
   -- cannot use regular entity "host" as the system interface
   -- doesn't have active hosts in memory, so we use a new
   -- entity "pinged_host"
   local ALERT_ENTITY = alertEntity("pinged_host")
   local ALERT_KEY    = "rtt"
   local ALERT_TYPE   = alertType("ping_issues")
   local ALERT_SEVERITY = alertSeverity("error")

   local alert_raised = ntop.getHashCache(ALERT_RAISED_KEY, ip_label)

   if engage then
      if alert_raised ~= "engaged" then
	 -- ENGAGE
	 ntop.setHashCache(ALERT_RAISED_KEY, ip_label, "engaged")
	 interface.engageAlert(ALERT_ENGINE, ALERT_ENTITY, ip_label, ALERT_KEY,
			       ALERT_TYPE, ALERT_SEVERITY,
			       formatAlertMessage(current_value, upper_threshold, ip_label, numeric_ip))
      end
   else -- release
      if alert_raised == "engaged" then
	 -- RELEASE
	 ntop.delHashCache(ALERT_RAISED_KEY, ip_label)
	 interface.releaseAlert(ALERT_ENGINE, ALERT_ENTITY, ip_label, ALERT_KEY,
				ALERT_TYPE,  ALERT_SEVERITY,
				formatAlertMessage(current_value, upper_threshold, ip_label, numeric_ip))
      end
   end
end

-- ##############################################

function probe.isEnabled()
  return(true)
end

-- ##############################################

function probe.loadSchemas(ts_utils)
  local schema

  schema = ts_utils.newSchema("monitored_host:rtt", {label = i18n("graphs.num_ms_rtt"), metrics_type = ts_utils.metrics.gauge})
  schema:addTag("host")
  schema:addMetric("millis_rtt")
end

-- ##############################################

function probe.stateful_alert_handler(numeric_ip, ip_label, trigger_alert, current_value, upper_threshold)
   local alert_raised = ntop.getHashCache(ALERT_RAISED_KEY, ip_label)

   if(trigger_alert == 1) then
      if(current_value == 0) then
	 if(debug) then print("[TRIGGER] Host "..ip_label.."/"..numeric_ip.." is unreacheable\n") end
      else
	 if(debug) then print("[TRIGGER] Host "..ip_label.."/"..numeric_ip.." [value: "..current_value.."][threshold: "..upper_threshold.."]\n") end
      end

      engageReleaseRTTAlert(true --[[ engage --]], ip_label, numeric_ip, current_value, upper_threshold)

   else
      if(debug) then print("[OK] Host "..ip_label.."/"..numeric_ip.." [value: "..current_value.."][threshold: "..upper_threshold.."]\n") end

      engageReleaseRTTAlert(false --[[ release --]], ip_label, numeric_ip, current_value, upper_threshold)
   end
end

-- ##############################################

function probe.runTask(when, ts_utils)
  local hosts = rtt_utils.getHosts()
  local pinged_hosts = {}
  local max_latency = {}

  if(debug) then
     print("[RTT] Script started\n")
  end

  -- cleanup possibly engaged alerts for hosts
  -- which are no longer among the pinged hosts
  for key, status in pairs(ntop.getHashAllCache(ALERT_RAISED_KEY) or {}) do
     if status == "engaged" and not hosts[key] then
	engageReleaseRTTAlert(false --[[ release --]], key)
     end
  end

  if table.empty(hosts) then
    return
  end

  for key, host in pairs(hosts) do
     local host_label = host.host
     local ip_address = host_label
     local is_v6

     if(host.iptype == "ipv6") then
	is_v6 = true
     else
	is_v6 = false
     end
     
     if(not isIPv4(host_label) and not(is_v6)) then
       ip_address = ntop.resolveHostV4(host_label)

       if(ip_address == nil) then
	  print("[RTT] Could not resolve IPv4 host: ".. host_label .."\n")
	  goto continue
       end
     elseif(not isIPv6(host_label) and is_v6) then
	ip_address = ntop.resolveHostV6(host_label)

	if(ip_address == nil) then
	  print("[RTT] Could not resolve IPv6 host: ".. host_label .."\n")
	  goto continue
	end
     end

     if(debug) then
	print("[RTT] Pinging "..ip_address.."/"..host_label.."\n")
     end

     ntop.pingHost(host_label, is_v6)
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

	ts_utils.append("monitored_host:rtt", {host = key, millis_rtt = rtt}, when)

	rtt = tonumber(rtt)
	rtt_utils.setLastRttUpdate(key, when, rtt, host)
	
	if(max_rtt and (rtt > max_rtt)) then
	   probe.stateful_alert_handler(host, key, 1, rtt, max_rtt)
	else
	   probe.stateful_alert_handler(host, key, 0, rtt, max_rtt)
	end
	
	pinged_hosts[host] = nil -- Remove key
     end
  end
  
  for ip,label in pairs(pinged_hosts) do
     probe.stateful_alert_handler(ip, label, 1, 0, 0)
  end

  if(debug) then
     print("[RTT] Script is over\n")
  end
end

-- ##############################################

return probe
