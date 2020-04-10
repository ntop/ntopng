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

  -- Exclude this script in Windows (as the ICMP monitor is not working there)
  windows_exclude = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},

  gui = {
    i18n_title = "rtt_stats.active_monitoring",
    i18n_description = "rtt_stats.active_monitoring_description",
  },
}

-- ##############################################

local function pingIssuesType(value, threshold, ip, granularity)
  return({
    alert_type = alert_consts.alert_types.alert_ping_issues,
    alert_severity = alert_consts.alert_severities.warning,
    alert_granularity = granularity,
    alert_type_params = {
      value = value, threshold = threshold, ip = ip,
    }
  })
end

-- ##############################################

local function triggerRttAlert(numeric_ip, ip_label, current_value, upper_threshold, granularity)
  local entity_info = alerts_api.pingedHostEntity(ip_label)
  local type_info = pingIssuesType(current_value, upper_threshold, numeric_ip, granularity)

  return alerts_api.trigger(entity_info, type_info)
end

-- ##############################################

local function releaseRttAlert(numeric_ip, ip_label, current_value, upper_threshold, granularity)
  local entity_info = alerts_api.pingedHostEntity(ip_label)
  local type_info = pingIssuesType(current_value, upper_threshold, numeric_ip, granularity)

  return alerts_api.release(entity_info, type_info)
end

-- ##############################################

local function run_rtt_check(params, all_hosts, granularity)
  local hosts_rtt = {}
  local when = params.when

  if(do_trace) then
     print("[RTT] Script started\n")
  end

  if table.empty(all_hosts) then
    return
  end

  local hosts_by_plugin = rtt_utils.getHostsByPlugin(all_hosts)

  -- Invoke the check functions
  for _, info in pairs(hosts_by_plugin) do
    info.measurement.check(info.hosts, granularity)
  end

  -- Wait some seconds for the results
  ntop.msleep(3000)

  -- Get the results
  for _, info in pairs(hosts_by_plugin) do
    for k, v in pairs(info.measurement.collect_results(granularity) or {}) do
      v.measurement = info.measurement
      hosts_rtt[k] = v
    end
  end

  -- Parse the results
  for key, info in pairs(hosts_rtt) do
    local host = all_hosts[key]
    local rtt = info.value
    local resolved_host = info.resolved_addr or host.host
    local max_rtt = host.max_rtt
    local operator = info.measurement.operator or "gt"

    if params.ts_enabled then
       ts_utils.append("rtt_host:rtt_" .. granularity, {ifid = getSystemInterfaceId(), host = host.host, measure = host.measurement, millis_rtt = rtt}, when)
    end

    rtt_utils.setLastRttUpdate(key, when, rtt, resolved_host)

    if(max_rtt and ((operator == "lt" and (rtt < max_rtt))
        or (operator == "gt" and (rtt > max_rtt)))) then
      if(do_trace) then print("[TRIGGER] Host "..resolved_host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
      triggerRttAlert(resolved_host, key, rtt, max_rtt, granularity)
    else
      if(do_trace) then print("[OK] Host "..resolved_host.."/"..key.." [value: "..rtt.."][threshold: "..max_rtt.."]\n") end
      releaseRttAlert(resolved_host, key, rtt, max_rtt, granularity)
    end
  end

  -- Find the unreachable hosts
  for key, host in pairs(all_hosts) do
     local ip = host.host

     if(hosts_rtt[key] == nil) then
       if(do_trace) then print("[TRIGGER] Host "..ip.."/"..key.." is unreacheable\n") end
       triggerRttAlert(ip, key, 0, 0, granularity)
     end
  end

  if(do_trace) then
     print("[RTT] Script is over\n")
  end
end

-- ##############################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
  local hosts = rtt_utils.getHosts(nil, "min")

  run_rtt_check(params, hosts, "min")
end

-- ##############################################

-- Defines an hook which is executed every 5 minutes
script.hooks["5mins"] = function(params)
  local hosts = rtt_utils.getHosts(nil, "5mins")

  run_rtt_check(params, hosts, "5mins")
end

-- ##############################################

-- Defines an hook which is executed every hour
function script.hooks.hour(params)
  local hosts = rtt_utils.getHosts(nil, "hour")

  run_rtt_check(params, hosts, "hour")
end

-- ##############################################

return script
