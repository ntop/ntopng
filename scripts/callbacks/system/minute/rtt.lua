--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")
local rtt_utils = require("rtt_utils")

local probe = {
  name = "RTT Monitor",
  description = "Monitors the round trip time of an host",
  has_own_page = true, -- this module has a dedicated page in the menu
}

local debug = false

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
   if(trigger_alert == 1) then
      if(current_value == 0) then
	 print("[TRIGGER] Host "..ip_label.."/"..numeric_ip.." in unreacheable\n")
      else
	 print("[TRIGGER] Host "..ip_label.."/"..numeric_ip.." [value: "..current_value.."][threshold: "..upper_threshold.."]\n")
      end
   else
      print("[OK] Host "..ip_label.."/"..numeric_ip.." [value: "..current_value.."][threshold: "..upper_threshold.."]\n")
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

	-- TODO add IPv6 support in Ping.cpp, otherwise it crashes
	print("[RTT] TODO IPv6 host: ".. host_label .."\n")
	goto continue
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
	local key   = pinged_hosts[host]
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
