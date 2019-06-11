--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")

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

  schema = ts_utils.newSchema("host:rtt", {label = i18n("graphs.num_ms_rtt"), metrics_type = ts_utils.metrics.gauge})
  schema:addTag("host")
  schema:addTag("label")
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
  local hosts = ntop.getHashAllCache("ntopng.prefs.rtt_hosts")
  local pinged_hosts = {}
  local max_latency = {}

  if(debug) then
     print("[RTT] Script started\n")
  end
  
  if table.empty(hosts) then
    return
  end

  for ip_name, max_rtt in pairs(hosts) do
     -- Host format is <IP>@<label>
     local e = string.split(ip_name, "%@")
     local ip_address = e[1]
     local host_label = e[2]

     if(debug) then
	print("[RTT] Pinging "..ip_address.."/"..host_label.."\n")
     end
     
     ntop.pingHost(ip_address)
     pinged_hosts[ip_address] = host_label
     max_latency[ip_address]  = tonumber(max_rtt)
  end

  ntop.msleep(2000) -- wait results
  
  local res = ntop.collectPingResults()

  if(res ~= nil) then
     for host, rtt in pairs(res) do
	local max_rtt = max_latency[host]
	local label   = pinged_hosts[host]
	ts_utils.append("host:rtt", {host = host, label = label, millis_rtt = rtt}, when)

	rtt = tonumber(rtt)
	
	if(max_rtt and (rtt > max_rtt)) then
	   probe.stateful_alert_handler(host, label, 1, rtt, max_rtt)
	else
	   probe.stateful_alert_handler(host, label, 0, rtt, max_rtt)
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
