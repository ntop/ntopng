--
-- (C) 2019-20 - ntop.org
--

local rtt_utils = {}
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

function rtt_utils.setLastRttUpdate(key, when, rtt, ipaddress)
  ntop.setCache(rtt_last_updates_key(key), string.format("%u@%.2f@%s", when, rtt, ipaddress))
end

-- ##############################################

-- Note: alerts requires a unique key to be used in order to identity the
-- entity. This key is also used internally as a key into the lua tables.
function rtt_utils.getRttHostKey(host, measurement)
  return(string.format("%s@%s", measurement, host))
end

local function key2rtthost(host)
  local parts = string.split(host, "@")

  if(parts and (#parts == 2)) then
    return parts[2], parts[1]
  end
end

-- ##############################################

function rtt_utils.getLastRttUpdate(host, measurement)
  local key = rtt_utils.getRttHostKey(host, measurement)
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
function rtt_utils.formatRttHost(host, measurement)
  return(string.format("%s://%s", measurement, host))
end

-- ##############################################

function rtt_utils.key2host(host_key)
  local host, measurement = key2rtthost(host_key)

  return {
    label = rtt_utils.formatRttHost(host, measurement),
    measurement = measurement,
    host = host,
  }
end

-- ##############################################

local function deserializeRttPrefs(host_key, val, config_only)
  local rv

  if config_only then
    rv = {}
  else
    rv = rtt_utils.key2host(host_key)
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

function rtt_utils.hasHost(host, measurement)
  local host_key = rtt_utils.getRttHostKey(host, measurement)
  local res = ntop.getHashCache(rtt_hosts_key, host_key)

  return(not isEmptyString(res))
end

-- ##############################################

function rtt_utils.getHosts(config_only, granularity)
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

function rtt_utils.resetConfig()
  local hosts = rtt_utils.getHosts()

  for k,v in pairs(hosts) do
    rtt_utils.deleteHost(v.host, v.measurement)
  end

  ntop.delCache(rtt_hosts_key)
end

-- ##############################################

function rtt_utils.getHost(host, measurement)
  local host_key = rtt_utils.getRttHostKey(host, measurement)
  local val = ntop.getHashCache(rtt_hosts_key, host_key)

  if not isEmptyString(val) then
    return deserializeRttPrefs(host_key, val)
  end
end

-- ##############################################

function rtt_utils.addHost(host, measurement, rtt_value, granularity)
  local host_key = rtt_utils.getRttHostKey(host, measurement)

  ntop.setHashCache(rtt_hosts_key, host_key, serializeRttPrefs({
    max_rtt = tonumber(rtt_value) or 500,
    granularity = granularity or "min",
  }))
end

-- ##############################################

function rtt_utils.deleteHost(host, measurement)
  local ts_utils = require("ts_utils")
  local alerts_api = require("alerts_api")
  local alert_utils = require("alert_utils")

  -- NOTE: system interface must be manually sected and then unselected
  local old_iface = tostring(interface.getId())
  interface.select(getSystemInterfaceId())

  local host_key = rtt_utils.getRttHostKey(host, measurement)
  local rtt_host_entity = alerts_api.pingedHostEntity(host_key)
  local old_ifname = ifname

  -- Release any engaged alerts of the host
  alerts_api.releaseEntityAlerts(rtt_host_entity)

  -- Delete the host RRDs
  ts_utils.delete("rtt_host", {ifid=getSystemInterfaceId(), host=host, measure=measurement})

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

  local measurements_path = plugins_utils.getPluginDataDir("rtt", "measurements")

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

function rtt_utils.getHostsByPlugin(all_hosts)
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

function rtt_utils.getAvailableMeasurements()
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

function rtt_utils.getAvailableGranularities(measurement)
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

function rtt_utils.getMeasurementInfo(measurement)
  loadRttPlugins()

  local m_info = loaded_measurements[measurement]

  if(not m_info) then
    return(nil)
  end

  return(m_info.measurement)
end

-- ##############################################

function rtt_utils.getMeasurementsInfo()
  loadRttPlugins()

  local rv = {}

  for k, v in pairs(loaded_measurements) do
    rv[k] = v.measurement
  end

  return(rv)
end

-- ##############################################

return rtt_utils
