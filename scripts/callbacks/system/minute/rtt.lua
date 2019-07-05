--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local rtt_utils = require("rtt_utils")
local format_utils = require("format_utils")
local alerts = require("alerts_api")

local probe = {
  name = "RTT Monitor",
  description = "Monitors the round trip time of an host",
  page_script = "rtt_stats.lua",
  page_order = 1500,
}

local debug = false

-- ##############################################

local function formatAlertMessage(alert, metadata)
   local msg
   -- example of an ip label:
   -- google-public-dns-b.google.com@ipv4@icmp/216.239.38.120
   local ip_label = alert.label:split("@")[1]
   local numeric_ip = alert.ip

   if numeric_ip and numeric_ip ~= ip_label then
      numeric_ip = string.format("[%s]", numeric_ip)
   else
      numeric_ip = ""
   end

   if(alert.value == 0) then -- host unreachable
      msg = i18n("alert_messages.ping_host_unreachable",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip})
   else -- host too slow
      msg = i18n("alert_messages.ping_rtt_too_slow",
		 {ip_label = ip_label,
		  numeric_ip = numeric_ip,
		  rtt_value = format_utils.round(alert.value, 2),
		  maximum_rtt = alert.threashold})
   end

   return msg
end

-- ##############################################

-- cannot use regular entity "host" as the system interface
-- doesn't have active hosts in memory, so we use a new
-- entity "pinged_host"
local ping_issues_alert = alerts:newAlert({
   periodicity = "min",
   type = "ping_issues",
   severity = "error",
   entity = "pinged_host",
   formatter = formatAlertMessage,
})

-- ##############################################

function probe.isEnabled()
  return(not ntop.isWindows())
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

function probe.emitRttAlert(numeric_ip, ip_label, current_value, upper_threshold)
   ping_issues_alert:trigger(ip_label, {
      value = current_value,
      threashold = upper_threshold,
      label = ip_label,
      ip = numeric_ip,
   })
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

	ts_utils.append("monitored_host:rtt", {ifid = getSystemInterfaceId(), host = key, millis_rtt = rtt}, when)

	rtt = tonumber(rtt)
	rtt_utils.setLastRttUpdate(key, when, rtt, host)
	
	if(max_rtt and (rtt > max_rtt)) then
     if(debug) then print("[TRIGGER] Host "..host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
     probe.emitRttAlert(host, key, rtt, max_rtt)
	else
     if(debug) then print("[OK] Host "..host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
	end
	
	pinged_hosts[host] = nil -- Remove key
     end
  end
  
  for ip,label in pairs(pinged_hosts) do
     probe.emitRttAlert(ip, label, 0, 0)
     if(debug) then print("[TRIGGER] Host "..ip.."/"..label.." is unreacheable\n") end
  end

  if(debug) then
     print("[RTT] Script is over\n")
  end
end

-- ##############################################

return probe
