--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local checks = require("checks")
local other_alert_keys = require "other_alert_keys"

local am_utils = {}
local ts_utils = require "ts_utils_core"
local json = require("dkjson")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local lua_path_utils = require("lua_path_utils")

local supported_granularities = {
  ["min"] = "alerts_thresholds_config.every_minute",
  ["5mins"] = "alerts_thresholds_config.every_5_minutes",
  ["hour"] = "alerts_thresholds_config.hourly",
}

-- Indexes in the hour stats array
local HOUR_STATS_OK = 1
local HOUR_STATS_EXCEEDED = 2
local HOUR_STATS_UNREACHABLE = 3

local do_trace = false

local active_monitoring = {
   -- Script category
   category = checks.check_categories.active_monitoring,

   default_enabled = true,
   alert_id = other_alert_keys.alert_am_threshold_cross,
}

-- ##############################################

local am_hosts_key = string.format("ntopng.prefs.ifid_%d.am_hosts", getSystemInterfaceId())

-- ##############################################

-- @brief Key used to save the result of the measurement (if requested)
--        Used for example to save the page fetched with HTTP/HTTPs measurements
local function am_last_result_key(key)
  return string.format("ntopng.cache.ifid_%d.am_hosts.last_result." .. key, getSystemInterfaceId())
end

-- ##############################################

local function am_last_updates_key(key)
  return string.format("ntopng.cache.ifid_%d.am_hosts.last_update_v1." .. key, getSystemInterfaceId())
end

local function am_hour_stats_key(key)
  return string.format("ntopng.cache.ifid_%d.am_hosts.hour_stats." .. key, getSystemInterfaceId())
end

-- ##############################################

function am_utils.setLastResult(key, last_result)
   if not isEmptyString(last_result) then
      ntop.setCache(am_last_result_key(key), last_result)
   end
end

-- ##############################################

function am_utils.setLastAmUpdate(key, when, value, ipaddress, jitter, mean)
  local v = {
    when = when,
    value = tonumber(value),
    ip = ipaddress,
    jitter = tonumber(jitter),
    mean = tonumber(mean),
  }

  ntop.setCache(am_last_updates_key(key), json.encode(v))
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

function am_utils.dropHourStats(host_key)
  ntop.delCache(am_hour_stats_key(host_key))
end

-- ##############################################

-- Note: alerts requires a unique key to be used in order to identity the
-- entity. This key is also used internally as a key into the lua tables.
function am_utils.getAmHostKey(host, measurement)
  return(string.format("%s@%s", measurement, host))
end

-- @brief Extract the measurement and the host from the key
--        which is the concatenation of <measurement>@<host>
local function key2amhost(host)
   -- Examples: http@https://maina:maina2@develv5:3003/lua/cane
   --           https://maina:maina2@develv5:3003/lua/cane
  local measurement, amhost = string.match(host, "^([^@]+)@(.+)")

  if measurement and amhost then
     return amhost, measurement
  end
end

-- ##############################################

function am_utils.getLastAmUpdate(host, measurement)
  local key = am_utils.getAmHostKey(host, measurement)
  local val = ntop.getCache(am_last_updates_key(key))

  if not isEmptyString(val) then
    val = json.decode(val)
  else
    val = nil
  end

  if val ~= nil then
    return val
  end
end

-- ##############################################

-- @brief Returns the possibly saved result of a measurement
function am_utils.getLastResult(host, measurement)
  local key = am_utils.getAmHostKey(host, measurement)
  local val = ntop.getCache(am_last_result_key(key))

  if not isEmptyString(val) then
     return val
  end

  return nil
end

-- ##############################################

-- @brief Check if this is an infrastructure active monitoring url
local function is_infrastructure(host)
   if not ntop.isEnterpriseM() or isEmptyString(host) then
      return false, nil
   end

   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
   local infrastructure_utils = require("infrastructure_utils")

   -- The host is considered an infrastructure host if it contains the endpoint in the name
   if host:find(infrastructure_utils.ENDPOINT_TO_EXTRACT_DATA) or host:find(infrastructure_utils.SUFFIX_THROUGHPUT) then
      local instance = infrastructure_utils.get_instance_by_host(host)

      if not instance then
	 return false, nil
      else
	 return true, instance.alias
      end
   end

   return false, nil
end

-- ##############################################

-- Only used for the formatting, don't use as a key as the "/"
-- character is escaped in HTTP parameters
function am_utils.formatAmHost(host, measurement, isHtml)
  local m_info = am_utils.getMeasurementInfo(measurement)

  --if m_info and m_info.force_host then
    -- Only a single host is present, return it
    --return(host)
  --end

  if(host == nil) then
     return(nil)
  end

  local res = host
  local is_infr, infr_name = is_infrastructure(host)

  -- Make a smarter way to determine infrastructure labels
  if is_infr then

     -- Make a nicer label for infrastructure hosts
     -- If the am host contains a name for the infrastructure use it
     if isHtml then
      res = infr_name .. " <i class='fas fa-building'></i>"
     else
      res = infr_name .. " [".. i18n("infrastructure_dashboard.infrastructure") .. "]"
    end
  else
    res = host
  end

  return res
end

-- ##############################################

function am_utils.key2host(host_key)
  local host, measurement = key2amhost(host_key)

  return {
    label = am_utils.formatAmHost(host, measurement, false),
    is_infrastructure = is_infrastructure(host),
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
      rv.host_key = host_key
      rv.show_iface = false
      rv.ifname = v.ifname or ''
      rv.threshold = tonumber(v.threshold) or 500
      rv.granularity = v.granularity or "min"
      rv.token = v.token
      rv.save_result = v.save_result
      rv.readonly = v.readonly
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
      if config_only then
        rv[host_key] = host
      else
        -- Ensure that the measurement is still available
        local m_info = am_utils.getMeasurementInfo(host.measurement)

        if(m_info ~= nil) then
          rv[host_key] = host
        end
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

-- @brief Add and host as part of the active monitoring
-- @param measurement A string with the type of measurement which will be performed
-- @param am_value A number used as threshold con consider the measurement failed
-- @param granularity One of `supported_granularities`, indicating the granularity of the measurement
-- @param token A string with an ntopng `token` used to fetch data from other ntopngs in a federation [optional]
-- @param save_result Whether the result fetched with the measure should be saved (e.g., the HTTP response) [optional]
-- @param readonly Bool used by the GUI to know if, when true, an entry is considered read only hence it cannot be modified/deleted [optional]
function am_utils.addHost(host, ifname, measurement, am_value, granularity, token, save_result, readonly)
  save_result = save_result or false
  readonly = readonly or false

  local host_key = am_utils.getAmHostKey(host, measurement)
  local show_iface = ntop.isPingIfaceAvailable()

  ntop.setHashCache(am_hosts_key, host_key, serializeAmPrefs({
    show_iface = show_iface,
    ifname = ifname or '',
    threshold = tonumber(am_value) or 500,
    granularity = granularity or "min",
    token = token, -- ntopng auth token
    save_result = save_result, -- save the result
    readonly = readonly,
  }))
end

-- ##############################################

function am_utils.discardHostTimeseries(host, measurement)
  ts_utils.delete("am_host", {ifid=getSystemInterfaceId(), host=host, metric=measurement})
end

-- ##############################################

function am_utils.deleteHost(host, measurement)
  local ts_utils = require("ts_utils")
  -- local alert_utils = require("alert_utils")

  -- NOTE: system interface must be manually sected and then unselected
  local old_iface = tostring(interface.getId())
  interface.select(getSystemInterfaceId())

  local host_key = am_utils.getAmHostKey(host, measurement)
  local am_host_entity = alerts_api.amThresholdCrossEntity(host_key)

  -- Release any engaged alerts of the host
  alerts_api.releaseEntityAlerts(am_host_entity)

  am_utils.discardHostTimeseries(host, measurement)

  -- Remove possibly saved results
  ntop.delCache(am_last_result_key(host_key))

  -- Remove the redis keys of the host
  ntop.delCache(am_last_updates_key(host_key))
  am_utils.dropHourStats(host_key)

  ntop.delHashCache(am_hosts_key, host_key)

  -- Select the old interface
  interface.select(old_iface)
end

-- ##############################################

local loaded_am_scripts = {}
local loaded_measurements = {}

local function loadAmScripts()
   if not table.empty(loaded_am_scripts) then
      return
   end

   local measurements_path = dirs.installdir .. "/scripts/lua/modules/measurements/"
   lua_path_utils.package_path_prepend(measurements_path)

   for fname in pairs(ntop.readdir(measurements_path)) do
      if(not string.ends(fname, ".lua")) then
	 goto continue
      end

      local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
      local script = require(mod_fname)

      if not script then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Could not load '%s'", mod_fname))
	 package.loaded[mod_fname] = nil
	 goto continue
      end

      if not script.measurements then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("'measurements' section missing in '%s'", mod_fname))
	 package.loaded[mod_fname] = nil
	 goto continue
      end

      if script.setup then
	 -- A setup function exists, call it to determine if the script is available
	 if(script.setup() == false) then
	    package.loaded[mod_fname] = nil
	    goto continue
	 end
      end

      -- Check that the measurements does not exist
      for _, measurement in pairs(script.measurements) do
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

	 loaded_measurements[measurement.key] = {script=script, measurement=measurement}

	 ::skip::
      end

      script.key = mod_fname
      loaded_am_scripts[mod_fname] = script

      ::continue::
   end

  loaded_measurements['vulnerability_scan'] = { measurement = { i18n_label = "active_monitoring_stats.vulnerability_scan" }}
  loaded_measurements['ports_changes_detected'] = { measurement = { i18n_label = "active_monitoring_stats.ports_changes_detected" }}
  loaded_measurements['cve_changes_detected'] = { measurement = { i18n_label = "active_monitoring_stats.cve_changes_detected" }}
end

-- ##############################################

--! @brief Splits the hosts list by measurement.
--! @param all_hosts the host list, whose format matches am_utils.getHosts()
--! @return a table measurement_key -> <script, measurement, hosts>
function am_utils.getHostsByMeasurement(all_hosts)
  local hosts_by_measurement = {}

  loadAmScripts()

  for key, host in pairs(all_hosts) do
    local measurement = host.measurement
    local m_info = loaded_measurements[measurement]

    if not m_info then
      traceError(TRACE_WARNING, TRACE_CONSOLE, "Unknown measurement: " .. measurement)
    else
      local measurement_key = m_info.measurement.key

      if not hosts_by_measurement[measurement_key] then
	hosts_by_measurement[measurement_key] = {script = m_info.script, measurement = m_info.measurement, hosts = {}}
      end

      hosts_by_measurement[measurement_key].hosts[key] = host
    end
  end

  return(hosts_by_measurement)
end

-- ##############################################

--! @brief Get a list of measurements from the loaded Active Monitoring scripts
--! @return a list of measurements <title, value> for the gui.
function am_utils.getAvailableMeasurements()
  local measurements = {}

  loadAmScripts()

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

--! @brief Check if the specified measurement is available
--! @return true if available, false otherwise
function am_utils.isMeasurementAvailable(measurement)
  loadAmScripts()

  return(loaded_measurements[measurement] ~= nil)
end

-- ##############################################

--! @brief Get a list of granularities allowed the the measurements
--! @param measurement the measurement key for which the granularities should be returned
--! @return a list of allowed granularities <titlae, value> for the gui.
function am_utils.getAvailableGranularities(measurement)
  local granularities = {}

  loadAmScripts()

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
  loadAmScripts()

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
  loadAmScripts()

  local rv = {}

  for k, v in pairs(loaded_measurements) do
    rv[k] = v.measurement
  end

  return(rv)
end

-- ##############################################

local function amThresholdCrossType(value, threshold, ip, granularity, entity_info)
  local host = am_utils.key2host(entity_info.entity_val)
  local m_info = am_utils.getMeasurementInfo(host.measurement)

  local alert_type = alert_consts.alert_types.alert_am_threshold_cross.new(
     value,
     threshold,
     ip,
     host,
     m_info.operator,
     m_info.i18n_unit
  )

  alert_type:set_score_warning()
  alert_type:set_granularity(granularity)

  return alert_type
end

-- ##############################################

function am_utils.triggerAlert(numeric_ip, ip_label, current_value, upper_threshold, granularity)
  local entity_info = alerts_api.amThresholdCrossEntity(ip_label)
  local type_info = amThresholdCrossType(current_value, upper_threshold, numeric_ip, granularity, entity_info)

  if(current_value == 0) then
    -- Unreachable
    local host, measurement = key2amhost(ip_label)
    local info = am_utils.getMeasurementInfo(measurement)
    type_info:set_score_critical()

    if info and info.unreachable_alert_i18n then
      -- The measurement provides an alternative message for the alert
      type_info.alert_type_params.alt_i18n = info.unreachable_alert_i18n
    end
  end

  return type_info:trigger(entity_info)
end

-- ##############################################

function am_utils.releaseAlert(numeric_ip, ip_label, current_value, upper_threshold, granularity)
  local entity_info = alerts_api.amThresholdCrossEntity(ip_label)
  local type_info = amThresholdCrossType(current_value, upper_threshold, numeric_ip, granularity, entity_info)

  return type_info:release(entity_info)
end

-- ##############################################

-- @brief Checks if the `am_host` passed as parameter has alerts engaged
--        `am_host` is one of the hosts obtained with `am_utils.getHosts()`
-- @return True if the host has engaged alerts, false otherwise
function am_utils.hasAlerts(am_host)
   local am_key = am_utils.getAmHostKey(am_host.host, am_host.measurement)
   local entity_info = alerts_api.amThresholdCrossEntity(am_key)

   -- Active Monitored hosts alerts stay in the system interface,
   -- so there's currenty need to temporarily select it
   local old_ifid = interface.getId()
   interface.select(getSystemInterfaceId())

   local am_alert_store = require "am_alert_store".new()
   local engaged = am_alert_store:select_engaged(am_key)

   interface.select(tostring(old_ifid))

   return engaged and #engaged > 0
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

-- Resolve the domain name into an IP if necessary
function am_utils.resolveHost(domain_name)
   local ip_address = domain_name

   if not isIPv4(domain_name) and not isIPv6(domain_name) then
      -- Symbolic name, try first to resolve as IPv4, then as IPv6
      ip_address = ntop.resolveHost(domain_name, true --[[IPv4 --]])

      if not ip_address then
	 -- IPv4 resolution failed, attempt at resolving ipv6
	 ip_address = ntop.resolveHost(domain_name, false --[[IPv6 --]])
      end
   else
      -- Regular IPv4 or IPv6, no need to resolve
   end

   return ip_address
end

-- ##############################################

function am_utils.editHost(host, iface, measurement, threshold, granularity, token, save_result, readonly)
  local existing = am_utils.getHost(host, measurement)

  if(existing == nil) then
    return(false)
  end

  if(existing.granularity ~= granularity) then
    -- Need to discard the old timeseries as the granularity has changed
    am_utils.discardHostTimeseries(host, measurement)
  end

  local m_info = am_utils.getMeasurementInfo(measurement)
  local last_update = am_utils.getLastAmUpdate(host, measurement)

  if m_info and last_update then
    -- Recheck the threshold
    local key = am_utils.getAmHostKey(host, measurement)
    local value = last_update.value
    threshold = tonumber(threshold)

    -- Drop the hour stats if the threshold has changed
    if(existing.threshold ~= threshold) then
       am_utils.dropHourStats(key)
    end

    if((existing.granularity ~= granularity) or (existing.threshold ~= threshold)) then
      -- NOTE: system interface must be manually sected and then unselected
      local old_iface = tostring(interface.getId())
      interface.select(getSystemInterfaceId())

      -- Release any engaged alerts of the host
      alerts_api.releaseEntityAlerts(alerts_api.amThresholdCrossEntity(key))

      interface.select(old_iface)
    end
  end

  am_utils.addHost(host, iface, measurement, threshold, granularity, token, save_result, readonly)

  return(true)
end

-- ##############################################

function am_utils.run_am_check(when, all_hosts, granularity)
  local hosts_am = {}
  local resolved_unreachable_hosts = {}
  local am_schema = am_utils.getAmSchemaForGranularity(granularity)

  when = when - (when % 60)

  if(do_trace) then
     print("[ActiveMonitoring] Script started\n")
  end

  if(do_trace) then io.write(debug.traceback()) end

  if table.empty(all_hosts) then
     if(do_trace) then print("[ActiveMonitoring] Nothing to do ["..granularity.."]\n") end
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
    local calculate_scaling = true

    if info.calculate_scaling then
      calculate_scaling = info.calculate_scaling
    end
    if(do_trace) then
       print("[AM result] "..key.."\n")
       -- tprint(info)
    end

    if jitter then jitter = round(jitter, 2) end
    if mean then mean = round(mean, 2) end

    if areSystemTimeseriesEnabled() then
       local value = host_value

       if (calculate_scaling) and (info.measurement.chart_scaling_value) and (info.measurement.chart_scaling_value == 1) then
         value = value * info.measurement.chart_scaling_value
       end

       local ts_data = {ifid = getSystemInterfaceId(), host = host.host, metric = host.measurement, value = value}
       if(do_trace) then
	  print("[Writing AM timeseries ")
	  -- tprint(ts_data)
       end

       ts_utils.append(am_schema, ts_data, when)
    end

    am_utils.setLastAmUpdate(key, when, host_value, resolved_host, jitter, mean)
    alerts_api.setCheck(active_monitoring)

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

       if areSystemTimeseriesEnabled() then
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

return am_utils
