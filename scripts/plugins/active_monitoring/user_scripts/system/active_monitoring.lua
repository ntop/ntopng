--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local ts_utils = require("ts_utils_core")
local plugins_utils = require("plugins_utils")
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

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
    i18n_title = "active_monitoring_stats.active_monitoring",
    i18n_description = "active_monitoring_stats.active_monitoring_description",
  },
}

-- ##############################################

local function run_am_check(params, all_hosts, granularity)
  local hosts_am = {}
  local when = params.when
  local am_schema = am_utils.getAmSchemaForGranularity(granularity)

  if(do_trace) then
     print("[ActiveMonitoring] Script started\n")
  end

  if table.empty(all_hosts) then
    return
  end

  local hosts_by_plugin = am_utils.getHostsByPlugin(all_hosts)

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
      hosts_am[k] = v
    end
  end

  -- Parse the results
  for key, info in pairs(hosts_am) do
    local host = all_hosts[key]
    local host_value = info.value
    local resolved_host = info.resolved_addr or host.host
    local threshold = host.threshold
    local operator = info.measurement.operator 

    if params.ts_enabled then
       local value = host_value

       if info.measurement.chart_scaling_value then
         value = value * info.measurement.chart_scaling_value
       end

       ts_utils.append(am_schema, {ifid = getSystemInterfaceId(), host = host.host, measure = host.measurement, value = value}, when)
    end

    am_utils.setLastAmUpdate(key, when, host_value, resolved_host)

    if am_utils.hasExceededThreshold(threshold, operator, host_value) then
      if(do_trace) then print("[TRIGGER] Host "..resolved_host.."/"..key.." [value: "..host_value.."][threshold: "..threshold.."]\n") end

      am_utils.triggerAlert(resolved_host, key, host_value, threshold, granularity)
      am_utils.incNumExceededChecks(key, when)
    else
      if(do_trace) then print("[OK] Host "..resolved_host.."/"..key.." [value: "..host_value.."][threshold: "..threshold.."]\n") end

      am_utils.releaseAlert(resolved_host, key, host_value, threshold, granularity)
      am_utils.incNumOkChecks(key, when)
    end
  end

  -- Find the unreachable hosts
  for key, host in pairs(all_hosts) do
     local ip = host.host

     if(hosts_am[key] == nil) then
       if(do_trace) then print("[TRIGGER] Host "..ip.."/"..key.." is unreacheable\n") end
       am_utils.triggerAlert(ip, key, 0, 0, granularity)
       am_utils.incNumUnreachableChecks(key, when)

       if params.ts_enabled then
         -- Also write 0 in its timeseries to indicate that the host is unreacheable
         ts_utils.append(am_schema, {ifid = getSystemInterfaceId(), host = host.host, measure = host.measurement, value = 0}, when)
       end
     end
  end

  if(do_trace) then
     print("[ActiveMonitoring] Script is over\n")
  end
end

-- ##############################################

-- Defines an hook which is executed every minute
function script.hooks.min(params)
  local hosts = am_utils.getHosts(nil, "min")

  run_am_check(params, hosts, "min")
end

-- ##############################################

-- Defines an hook which is executed every 5 minutes
script.hooks["5mins"] = function(params)
  local hosts = am_utils.getHosts(nil, "5mins")

  run_am_check(params, hosts, "5mins")
end

-- ##############################################

-- Defines an hook which is executed every hour
function script.hooks.hour(params)
  local hosts = am_utils.getHosts(nil, "hour")

  run_am_check(params, hosts, "hour")
end

-- ##############################################

return script
