--
-- (C) 2019-20 - ntop.org
--

local am_utils = {}
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local os_utils = require("os_utils")

local supported_granularities = {
  ["min"] = "alerts_thresholds_config.every_minute",
  ["5mins"] = "alerts_thresholds_config.every_5_minutes",
  ["hour"] = "alerts_thresholds_config.hourly",
}

-- ##############################################

local rtt_hosts_key = string.format("ntopng.prefs.ifid_%d.system_rtt_hosts_v3", getSystemInterfaceId())

-- ##############################################

local function rtt_last_updates_key(key)
  return string.format("ntopng.cache.ifid_%d.system_rtt_hosts.last_update." .. key, getSystemInterfaceId())
end

-- ##############################################

function am_utils.setLastRttUpdate(key, when, rtt, ipaddress)
  ntop.setCache(rtt_last_updates_key(key), string.format("%u@%.2f@%s", when, rtt, ipaddress))
end

-- ##############################################

-- Note: alerts requires a unique key to be used in order to identity the
-- entity. This key is also used internally as a key into the lua tables.
function am_utils.getRttHostKey(host, measurement)
  return(string.format("%s@%s", measurement, host))
end

local function key2rtthost(host)
  local parts = string.split(host, "@")

  if(parts and (#parts == 2)) then
    return parts[2], parts[1]
  end
end

-- ##############################################

function am_utils.getLastRttUpdate(host, measurement)
  local key = am_utils.getRttHostKey(host, measurement)
  local val = ntop.getCache(rtt_last_updates_key(key))

  if(val ~= nil)then
    local parts = string.split(val, "@")

    if(parts and (#parts == 3)) then
      return {
        when = parts[1],
        value = parts[2],
        ip = parts[3],
      }
    end
  end
end

-- ##############################################

-- Only used for the formatting, don't use as a key as the "/"
-- character is escaped in HTTP parameters
function am_utils.formatRttHost(host, measurement)
  local m_info = am_utils.getMeasurementInfo(measurement)

  if m_info and m_info.force_host then
    -- Only a single host is present, return it
    return(host)
  end

  return(string.format("%s://%s", measurement, host))
end

-- ##############################################

function am_utils.key2host(host_key)
  local host, measurement = key2rtthost(host_key)

  return {
    label = am_utils.formatRttHost(host, measurement),
    measurement = measurement,
    host = host,
  }
end

-- ##############################################

function am_utils.getRttSchemaForGranularity(granularity)
  local alert_consts = require("alert_consts")
  local str_granularity

  if(tonumber(granularity) ~= nil) then
    str_granularity = alert_consts.sec2granularity(granularity)
  else
    str_granularity = granularity
  end

  return("am_host:rtt_" .. (str_granularity or "min"))
end

-- ##############################################

local function deserializeRttPrefs(host_key, val, config_only)
  local rv

  if config_only then
    rv = {}
  else
    rv = am_utils.key2host(host_key)
  end

  if(tonumber(val) ~= nil) then
    -- Old format is only a number
    rv.max_rtt = tonumber(val)
    rv.granularity = "min"
  else
    -- New format: json
    local v = json.decode(val)

    if v then
      rv.max_rtt = tonumber(v.max_rtt) or 500
      rv.granularity = v.granularity or "min"
    end
  end

  return(rv)
end

local function serializeRttPrefs(val)
  return json.encode(val)
end

-- ##############################################

function am_utils.hasHost(host, measurement)
  local host_key = am_utils.getRttHostKey(host, measurement)
  local res = ntop.getHashCache(rtt_hosts_key, host_key)

  return(not isEmptyString(res))
end

-- ##############################################

function am_utils.getHosts(config_only, granularity)
  local hosts = ntop.getHashAllCache(rtt_hosts_key) or {}
  local rv = {}

  for host_key, val in pairs(hosts) do
    local host = deserializeRttPrefs(host_key, val, config_only)

    if host and ((granularity == nil) or (host.granularity == granularity)) then
      rv[host_key] = host
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

  ntop.delCache(rtt_hosts_key)
end

-- ##############################################

function am_utils.getHost(host, measurement)
  local host_key = am_utils.getRttHostKey(host, measurement)
  local val = ntop.getHashCache(rtt_hosts_key, host_key)

  if not isEmptyString(val) then
    return deserializeRttPrefs(host_key, val)
  end
end

-- ##############################################

function am_utils.addHost(host, measurement, rtt_value, granularity)
  local host_key = am_utils.getRttHostKey(host, measurement)

  ntop.setHashCache(rtt_hosts_key, host_key, serializeRttPrefs({
    max_rtt = tonumber(rtt_value) or 500,
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
  local alerts_api = require("alerts_api")
  local alert_utils = require("alert_utils")

  -- NOTE: system interface must be manually sected and then unselected
  local old_iface = tostring(interface.getId())
  interface.select(getSystemInterfaceId())

  local host_key = am_utils.getRttHostKey(host, measurement)
  local rtt_host_entity = alerts_api.pingedHostEntity(host_key)
  local old_ifname = ifname

  -- Release any engaged alerts of the host
  alerts_api.releaseEntityAlerts(rtt_host_entity)

  am_utils.discardHostTimeseries(host, measurement)

  -- Remove the redis keys of the host
  ntop.delCache(rtt_last_updates_key(host_key))

  ntop.delHashCache(rtt_hosts_key, host_key)

  -- Select the old interface
  interface.select(old_iface)
end

-- ##############################################

local loaded_rtt_plugins = {}
local loaded_measurements = {}

local function loadRttPlugins()
  if not table.empty(loaded_rtt_plugins) then
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
    loaded_rtt_plugins[mod_fname] = plugin

    ::continue::
  end
end

-- ##############################################

--! @brief Splits the hosts list by plugin.
--! @param all_hosts the host list, whose format matches am_utils.getHosts()
--! @return a table plugin_key -> <plugin, measurement, hosts>
function am_utils.getHostsByPlugin(all_hosts)
  local hosts_by_plugin = {}

  loadRttPlugins()

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

--! @brief Get a list of measurements from the loaded RTT plugins
--! @return a list of measurements <title, value> for the gui.
function am_utils.getAvailableMeasurements()
  local measurements = {}

  loadRttPlugins()

  for k, v in pairsByKeys(loaded_measurements, asc) do
    measurements[#measurements + 1] = {
      title = k,
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

  loadRttPlugins()

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
  loadRttPlugins()

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
  loadRttPlugins()

  local rv = {}

  for k, v in pairs(loaded_measurements) do
    rv[k] = v.measurement
  end

  return(rv)
end

-- ##############################################

return am_utils
