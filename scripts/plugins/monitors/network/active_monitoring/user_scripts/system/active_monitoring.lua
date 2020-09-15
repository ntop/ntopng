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
  local resolved_unreachable_hosts = {}
  local when = params.when - (params.when % 60)
  local am_schema = am_utils.getAmSchemaForGranularity(granularity)

  if(do_trace) then
     print("[ActiveMonitoring] Script started\n")
  end

  if table.empty(all_hosts) then
    return
  end

  local hosts_by_measurement = am_utils.getHostsByMeasurement(all_hosts)

  -- Invoke the check functions
  for _, info in pairs(hosts_by_measurement) do
    info.measurement.check(info.hosts, granularity)
  end

  -- Wait some seconds for the results
  ntop.msleep(3000)

  -- Get the results
  for _, info in pairs(hosts_by_measurement) do
     local collected = info.measurement.collect_results(granularity)
     for k, v in pairs(collected or {}) do
      v.measurement = info.measurement

      if(v.value ~= nil) then
        hosts_am[k] = v
      elseif(v.resolved_addr ~= nil) then
        -- For unreachable hosts, still save the resolved address in order to
        -- properly report it into the alert message.
        resolved_unreachable_hosts[k] = v.resolved_addr
      end
    end
  end

  -- Parse the results
  for key, info in pairs(hosts_am) do
    local host = all_hosts[key]
    local host_value = round(info.value, 2)
    local resolved_host = info.resolved_addr or host.host
    local threshold = host.threshold
    local operator = info.measurement.operator
    local jitter = tonumber(info.jitter)
    local mean = tonumber(info.mean)

    if jitter then jitter = round(jitter, 2) end
    if mean then mean = round(mean, 2) end

    if params.ts_enabled then
       local value = host_value

       if info.measurement.chart_scaling_value then
         value = value * info.measurement.chart_scaling_value
       end

       local ts_data = {ifid = getSystemInterfaceId(), host = host.host, metric = host.measurement, value = value}
       ts_utils.append(am_schema, ts_data, when)
    end

    am_utils.setLastAmUpdate(key, when, host_value, resolved_host, jitter, mean)

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
       local resolved_host = resolved_unreachable_hosts[key] or ip

       am_utils.triggerAlert(resolved_host, key, 0, 0, granularity)
       am_utils.incNumUnreachableChecks(key, when)

       if params.ts_enabled then
         -- Also write 0 in its timeseries to indicate that the host is unreacheable
         ts_utils.append(am_schema, {ifid = getSystemInterfaceId(), host = host.host, metric = host.measurement, value = 0}, when)
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
