--
-- (C) 2019-20 - ntop.org
--

local am_utils = {}
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local os_utils = require("os_utils")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local supported_granularities = {
  ["min"] = "alerts_thresholds_config.every_minute",
  ["5mins"] = "alerts_thresholds_config.every_5_minutes",
  ["hour"] = "alerts_thresholds_config.hourly",
}

-- Indexes in the hour stats array
local HOUR_STATS_OK = 1
local HOUR_STATS_EXCEEDED = 2
local HOUR_STATS_UNREACHABLE = 3

-- ##############################################

local am_hosts_key = string.format("ntopng.prefs.ifid_%d.am_hosts", getSystemInterfaceId())

-- ##############################################

local function am_last_updates_key(key)
  return string.format("ntopng.cache.ifid_%d.am_hosts.last_update." .. key, getSystemInterfaceId())
end

local function am_hour_stats_key(key)
  return string.format("ntopng.cache.ifid_%d.am_hosts.hour_stats." .. key, getSystemInterfaceId())
end

-- ##############################################

function am_utils.setLastAmUpdate(key, when, value, ipaddress)
  ntop.setCache(am_last_updates_key(key), string.format("%u@%.2f@%s", when, value, ipaddress))
end

-- ##############################################

-- key: the host key
-- when: the update time
-- update_idx is one of HOUR_STATS_OK, HOUR_STATS_EXCEEDED, HOUR_STATS_UNREACHABLE
local function updateHourStats(key, when, update_idx)
  local redis_k = am_hour_stats_key(key)
  local hstats_data = ntop.getCache(redis_k)

  if(not isEmptyString(hstats_data)) then
    hstats_data = json.decode(hstats_data) or {}
  else
    hstats_data = {}
  end

  if(hstats_data.hstats == nil) then
    hstats_data.hstats = {}

    -- Initialize the per-hour stats
    -- Using Lua based index to avoid json conversion issues
    for i=1,24 do
      -- Keep compact, the format is {num_ok, num_exceeded, num_unreachable}
      hstats_data.hstats[i] = {0, 0, 0}
    end
  end

  local prev_dt = os.date("*t", hstats_data.when or 0)
  local cur_dt = os.date("*t", when)
  local hour_idx = (cur_dt.hour + 1)

  if(cur_dt.hour ~= prev_dt.hour) then
    -- Hour has changed, reset the bucket stats
    hstats_data.hstats[hour_idx] = {0, 0, 0}
  end

  local hour_stats = hstats_data.hstats[hour_idx]
  hour_stats[update_idx] = hour_stats[update_idx] + 1
  hstats_data.when = when

  ntop.setCache(redis_k, json.encode(hstats_data))
end

-- ##############################################

function am_utils.incNumOkChecks(key, when)
  return(updateHourStats(key, when, HOUR_STATS_OK))
end

function am_utils.incNumExceededChecks(key, when)
  return(updateHourStats(key, when, HOUR_STATS_EXCEEDED))
end

function am_utils.incNumUnreachableChecks(key, when)
  return(updateHourStats(key, when, HOUR_STATS_UNREACHABLE))
end

-- ##############################################

-- Retrieve the per-hour stats of the host.
-- The returned data has the hour as the table key (0 for midnight).
-- 
-- Example:
--
--  0 table
--  0.num_ok number 0
--  0.num_exceeded number 0
--  0.num_unreachable number 0
-- ...
function am_utils.getHourStats(host, measurement)
  local key = am_utils.getAmHostKey(host, measurement)
  local redis_k = am_hour_stats_key(key)
  local hour_stats = ntop.getCache(redis_k)

  if(isEmptyString(hour_stats)) then
    return(nil)
  end

  hour_stats = json.decode(hour_stats)

  if((hour_stats == nil) or (hour_stats.hstats == nil)) then
    return(nil)
  end

  local res = {}

  -- Expand the result with labels
  for i=1,24 do
    local pt = hour_stats.hstats[i]

    -- Convert in an hour based table
    res[tostring(i-1)] = {
      num_ok = pt[HOUR_STATS_OK],
      num_exceeded = pt[HOUR_STATS_EXCEEDED],
      num_unreachable = pt[HOUR_STATS_UNREACHABLE],
    }
  end

  return(res)
end

-- ##############################################

-- Get the total host availability in the past day (0-100)%
-- nil is returned when no data is available.
-- An host is considered available when it is reachable and within the
-- threshold.
function am_utils.getAvailability(host, measurement)
  local key = am_utils.getAmHostKey(host, measurement)
  local redis_k = am_hour_stats_key(key)
  local hour_stats = ntop.getCache(redis_k)

  if(isEmptyString(hour_stats)) then
    return(nil)
  end

  hour_stats = json.decode(hour_stats)

  if((hour_stats == nil) or (hour_stats.hstats == nil)) then
    return(nil)
  end

  local tot_available = 0
  local tot_unavailable = 0
  local rc = {}
  
  for i=1,24 do
    local pt = hour_stats.hstats[i]

    if pt then
      tot_available = tot_available + pt[HOUR_STATS_OK]
      tot_unavailable = tot_unavailable + pt[HOUR_STATS_EXCEEDED] + pt[HOUR_STATS_UNREACHABLE]

      if((pt[HOUR_STATS_OK]+pt[HOUR_STATS_UNREACHABLE]+pt[HOUR_STATS_EXCEEDED]) == 0) then
	 color = 0
      elseif((pt[HOUR_STATS_UNREACHABLE]+pt[HOUR_STATS_EXCEEDED]) == 0) then
   	 color = 1
      elseif(((pt[HOUR_STATS_UNREACHABLE]+pt[HOUR_STATS_EXCEEDED]) > 0) and (pt[HOUR_STATS_OK] == 0)) then
   	 color = 2
      else
   	 color = 3
      end

      table.insert(rc, color)
    end
  end
  
  return rc, (tot_available * 100 / (tot_available + tot_unavailable))
end

-- ##############################################

-- Note: alerts requires a unique key to be used in order to identity the
-- entity. This key is also used internally as a key into the lua tables.
function am_utils.getAmHostKey(host, measurement)
  return(string.format("%s@%s", measurement, host))
end

local function key2amhost(host)
  local parts = string.split(host, "@")

  if(parts and (#parts == 2)) then
    return parts[2], parts[1]
  end
end

-- ##############################################

function am_utils.getLastAmUpdate(host, measurement)
  local key = am_utils.getAmHostKey(host, measurement)
  local val = ntop.getCache(am_last_updates_key(key))

  if(val ~= nil)then
    local parts = string.split(val, "@")

    if(parts and (#parts == 3)) then
      return {
        when = tonumber(parts[1]),
        value = tonumber(parts[2]),
        ip = parts[3],
      }
    end
  end
end

-- ##############################################

-- Only used for the formatting, don't use as a key as the "/"
-- character is escaped in HTTP parameters
function am_utils.formatAmHost(host, measurement)
  local m_info = am_utils.getMeasurementInfo(measurement)

  if m_info and m_info.force_host then
    -- Only a single host is present, return it
    return(host)
  end

  return(string.format("%s://%s", measurement, host))
end

-- ##############################################

function am_utils.key2host(host_key)
  local host, measurement = key2amhost(host_key)

  return {
    label = am_utils.formatAmHost(host, measurement),
    measurement = measurement,
    host = host,
  }
end

-- ##############################################

function am_utils.getAmSchemaForGranularity(granularity)
  local str_granularity

  if(tonumber(granularity) ~= nil) then
    str_granularity = alert_consts.sec2granularity(granularity)
  else
    str_granularity = granularity
  end

  return("am_host:val_" .. (str_granularity or "min"))
end

-- ##############################################

local function deserializeAmPrefs(host_key, val, config_only)
  local rv

  if config_only then
    rv = {}
  else
    rv = am_utils.key2host(host_key)
  end

  if(tonumber(val) ~= nil) then
    -- Old format is only a number
    rv.threshold = tonumber(val)
    rv.granularity = "min"
  else
    -- New format: json
    local v = json.decode(val)

    if v then
      rv.threshold = tonumber(v.threshold) or 500
      rv.granularity = v.granularity or "min"
    end
  end

  return(rv)
end

local function serializeAmPrefs(val)
  return json.encode(val)
end

-- ##############################################

function am_utils.hasHost(host, measurement)
  local host_key = am_utils.getAmHostKey(host, measurement)
  local res = ntop.getHashCache(am_hosts_key, host_key)

  return(not isEmptyString(res))
end

-- ##############################################

function am_utils.getHosts(config_only, granularity)
  local hosts = ntop.getHashAllCache(am_hosts_key) or {}
  local rv = {}

  for host_key, val in pairs(hosts) do
    local host = deserializeAmPrefs(host_key, val, config_only)

    if host and ((granularity == nil) or (host.granularity == granularity)) then
      -- Ensure that the measurement is still available
      local m_info = am_utils.getMeasurementInfo(host.measurement)

      if(m_info ~= nil) then
        rv[host_key] = host
      end
    end
  end

  return rv
end

-- ##############################################

function am_utils.resetConfig()
  local hosts = am_utils.getHosts()

  for k,v in pairs(hosts) do
    am_utils.deleteHost(v.host, v.measurement)
  end

  ntop.delCache(am_hosts_key)
end

-- ##############################################

function am_utils.getHost(host, measurement)
  local host_key = am_utils.getAmHostKey(host, measurement)
  local val = ntop.getHashCache(am_hosts_key, host_key)

  if not isEmptyString(val) then
    return deserializeAmPrefs(host_key, val)
  end
end

-- ##############################################

function am_utils.addHost(host, measurement, am_value, granularity)
  local host_key = am_utils.getAmHostKey(host, measurement)

  ntop.setHashCache(am_hosts_key, host_key, serializeAmPrefs({
    threshold = tonumber(am_value) or 500,
    granularity = granularity or "min",
  }))
end

-- ##############################################

function am_utils.discardHostTimeseries(host, measurement)
  ts_utils.delete("am_host", {ifid=getSystemInterfaceId(), host=host, measure=measurement})
end

-- ##############################################

function am_utils.deleteHost(host, measurement)
  local ts_utils = require("ts_utils")
  local alert_utils = require("alert_utils")

  -- NOTE: system interface must be manually sected and then unselected
  local old_iface = tostring(interface.getId())
  interface.select(getSystemInterfaceId())

  local host_key = am_utils.getAmHostKey(host, measurement)
  local am_host_entity = alerts_api.amThresholdCrossEntity(host_key)
  local old_ifname = ifname

  -- Release any engaged alerts of the host
  alerts_api.releaseEntityAlerts(am_host_entity)

  am_utils.discardHostTimeseries(host, measurement)

  -- Remove the redis keys of the host
  ntop.delCache(am_last_updates_key(host_key))

  ntop.delHashCache(am_hosts_key, host_key)

  -- Select the old interface
  interface.select(old_iface)
end

-- ##############################################

local loaded_am_plugins = {}
local loaded_measurements = {}

local function loadAmPlugins()
  if not table.empty(loaded_am_plugins) then
    return
  end

  local measurements_path = plugins_utils.getPluginDataDir("active_monitoring", "measurements")

  for fname in pairs(ntop.readdir(measurements_path)) do
    if(not string.ends(fname, ".lua")) then
      goto continue
    end

    local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
    local full_path = os_utils.fixPath(measurements_path .. "/" .. fname)
    local plugin = dofile(full_path)

    if(plugin == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load '%s'", full_path))
      goto continue
    end

    if(not (plugin.measurements)) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("'measurements' section missing in '%s'", full_path))
      goto continue
    end

    if(plugin.setup ~= nil) then
      -- A setup function exists, call it to determine if the plugin is available
      if(plugin.setup() == false) then
	goto continue
      end
    end

    -- Check that the measurements does not exist
    for _, measurement in pairs(plugin.measurements) do
      if(measurement.check == nil) then
	traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing 'check' function in '%s' measurement", measurement.key))
	goto skip
      end

      if(measurement.collect_results == nil) then
	traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing 'collect_results' function in '%s' measurement", measurement.key))
	goto skip
      end

      if(loaded_measurements[measurement.key]) then
	traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Measurement '%s' already defined in '%s'", measurement.key, loaded_measurements[measurement.key].key))
	goto skip
      end

      loaded_measurements[measurement.key] = {plugin=plugin, measurement=measurement}

      ::skip::
    end

    plugin.key = mod_fname
    loaded_am_plugins[mod_fname] = plugin

    ::continue::
  end
end

-- ##############################################

--! @brief Splits the hosts list by plugin.
--! @param all_hosts the host list, whose format matches am_utils.getHosts()
--! @return a table plugin_key -> <plugin, measurement, hosts>
function am_utils.getHostsByPlugin(all_hosts)
  local hosts_by_plugin = {}

  loadAmPlugins()

  for key, host in pairs(all_hosts) do
    local measurement = host.measurement
    local m_info = loaded_measurements[measurement]

    if not m_info then
      traceError(TRACE_WARNING, TRACE_CONSOLE, "Unknown measurement: " .. measurement)
    else
      local plugin_key = m_info.plugin.key

      if not hosts_by_plugin[plugin_key] then
	hosts_by_plugin[plugin_key] = {plugin = m_info.plugin, measurement = m_info.measurement, hosts = {}}
      end

      hosts_by_plugin[plugin_key].hosts[key] = host
    end
  end

  return(hosts_by_plugin)
end

-- ##############################################

--! @brief Get a list of measurements from the loaded Active Monitoring plugins
--! @return a list of measurements <title, value> for the gui.
function am_utils.getAvailableMeasurements()
  local measurements = {}

  loadAmPlugins()

  for k, v in pairsByKeys(loaded_measurements, asc) do
    local m = v.measurement

    measurements[#measurements + 1] = {
      title = i18n(m.i18n_label) or m.i18n_label,
      value = k,
    }
  end

  return(measurements)
end

-- ##############################################

--! @brief Get a list of granularities allowed the the measurements
--! @param measurement the measurement key for which the granularities should be returned
--! @return a list of allowed granularities <titlae, value> for the gui.
function am_utils.getAvailableGranularities(measurement)
  local granularities = {}

  loadAmPlugins()

  local m_info = loaded_measurements[measurement]

  if(not m_info) then
    return(granularities)
  end

  for _, k in ipairs(m_info.measurement.granularities) do
    local i18n_title = supported_granularities[k]

    if i18n_title then
      granularities[#granularities + 1] = {
	title = i18n(i18n_title),
	value = k,
      }
    end
  end

  return granularities
end

-- ##############################################

--! @brief Get the metadata of a specific measurement
--! @param measurement the measurement key
--! @return the measurement metadata on success, nil on failure
function am_utils.getMeasurementInfo(measurement)
  loadAmPlugins()

  local m_info = loaded_measurements[measurement]

  if(not m_info) then
    return(nil)
  end

  return(m_info.measurement)
end

-- ##############################################

--! @brief Get the metadata of all the loaded measurements
--! @return a list containing the measurements metadata
function am_utils.getMeasurementsInfo()
  loadAmPlugins()

  local rv = {}

  for k, v in pairs(loaded_measurements) do
    rv[k] = v.measurement
  end

  return(rv)
end

-- ##############################################

local function amThresholdCrossType(value, threshold, ip, granularity, entity_info)
  local host = am_utils.key2host(entity_info.alert_entity_val)
  local m_info = am_utils.getMeasurementInfo(host.measurement)

  local alert_type = alert_consts.alert_types.alert_am_threshold_cross.builder(
     alert_consts.alert_severities.warning,
     alert_consts.alerts_granularities[granularity],
     value,
     threshold,
     ip,
     host,
     m_info.operator,
     m_info.i18n_unit
  )

  return alert_type
end

-- ##############################################

function am_utils.triggerAlert(numeric_ip, ip_label, current_value, upper_threshold, granularity)
  local entity_info = alerts_api.amThresholdCrossEntity(ip_label)
  local type_info = amThresholdCrossType(current_value, upper_threshold, numeric_ip, granularity, entity_info)

  return alerts_api.trigger(entity_info, type_info)
end

-- ##############################################

function am_utils.releaseAlert(numeric_ip, ip_label, current_value, upper_threshold, granularity)
  local entity_info = alerts_api.amThresholdCrossEntity(ip_label)
  local type_info = amThresholdCrossType(current_value, upper_threshold, numeric_ip, granularity, entity_info)

  return alerts_api.release(entity_info, type_info)
end

-- ##############################################

function am_utils.hasExceededThreshold(threshold, operator, value)
  operator = operator or "gt"

  if(threshold and ((operator == "lt" and (value < threshold))
      or (operator == "gt" and (value > threshold)))) then
    return(true)
  else
    return(false)
  end
end

-- ##############################################

return am_utils
