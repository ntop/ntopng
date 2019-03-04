--
-- (C) 2017-18 - ntop.org
--

local json = require "dkjson"

local tracker = {}


--! @brief Log a function call providing name and arguments
--! @param f_name is the function name
--! @param f_args is a table with the arguments
function tracker.log(f_name, f_args)
  local stats = interface.getStats()

  if stats == nil then
    -- this is running before interfaces are instantiated
    traceError(TRACE_INFO, TRACE_CONSOLE,
      "Cannot log " .. f_name .. " call as interfaces are not instantiated yet!")
    return
  end

  local ifid = stats.id

  local jobj = { 
    scope = 'function',
    name = f_name,
    params = f_args,
    ifid = ifid
  }

  local entity = alertEntity("user")

  local entity_value = 'system'
  if _SESSION and _SESSION["user"] then
     entity_value = _SESSION["user"]
  end

  local alert_type = alertType("alert_user_activity")
  local alert_severity = alertSeverity("info")
  local alert_json = json.encode(jobj)

  -- tprint(alert_json)

  local old_iface = ifid
  local sys_iface = getFirstInterfaceId()
  interface.select(tostring(sys_iface))

  interface.storeAlert(entity, entity_value, alert_type, alert_severity, alert_json)

  interface.select(tostring(old_iface))
end

--! @brief Filter setPref calls to be logged based on the actual preference
--! @param key is the preference key in redis
--! @return true if the preference should be logged, false otherwise
local function tracker_filter_pref(key)
  local k = key:gsub("^ntopng%.prefs%.", "")

  if k == "disable_alerts_generation" or
     k == "mining_alerts" or
     k == "probing_alerts" or
     k == "ssl_alerts" or
     k == "dns_alerts" or
     k == "ip_reassignment_alerts" or
     k == "remote_to_remote_alerts" or
     k == "mining_alerts" or
     k == "host_blacklist" or
     k == "device_protocols_alerts" or
     k == "alerts.device_first_seen_alert" or
     k == "alerts.device_connection_alert" or
     k == "alerts.pool_connection_alert" or
     k == "alerts.external_notifications_enabled" or
     k == "alerts.email_notifications_enabled" or
     k == "alerts.slack_notifications_enabled" or
     k == "alerts.syslog_notifications_enabled" or
     k == "alerts.nagios_notifications_enabled" or
     k == "alerts.webhook_notifications_enabled" or
     starts(k, "alerts.email_") or 
     starts(k, "alerts.smtp_") or 
     starts(k, "alerts.slack_") or 
     starts(k, "alerts.webhook_") or 
     starts(k, "alerts.nagios_") or 
     starts(k, "nagios_")
  then
    return true
  end

  return false
end

local function enablingAlertsGeneration(f_name, f_args)
  return (f_name == "setPref" and 
          f_args[1] ~= nil and f_args[1] == "ntopng.prefs.disable_alerts_generation" and 
          f_args[2] ~= nil and f_args[2] == "0")
end

local function purgingAlerts(f_name)
  return (f_name == "checkDeleteStoredAlerts")
end

--! @brief Filter function calls to be logged based on function name or arguments
--! @param f_name is the function name
--! @param f_args is a table with the arguments
--! @return true if the call should be logged, false otherwise
local function tracker_filter(f_name, f_args)
  if (f_name == 'setPref' and (f_args[1] == nil or not tracker_filter_pref(f_args[1]))) then
    return false
  end

  return true
end

--! @brief Return a 'wrapper' function to be used for tracking function calls
--! @param f is the function to wrap
--! @param name is the name of the function (optional, debug.getinfo will be used if name is not provided)
--! @return the wrapper function to be used in place of the original function
function tracker.hook(f, name)
  return function(...)
    local f_name = name

    if f_name == nil then
      f_name = debug.getinfo(1, "n").name
    end

    local f_args = {}
    for k, v in pairs({...}) do
      if (f_name == 'addUser'           and k == 3) or
         (f_name == 'resetUserPassword' and k == 4) then
        -- hiding password
        f_args[k] = ''
      else
        f_args[k] = tostring(v)
      end
    end

    local track_call = (f_name ~= nil and tracker_filter(f_name, f_args))
    local track_after_call = (track_call and (purgingAlerts(f_name) or enablingAlertsGeneration(f_name, f_args)))

    if track_call and not track_after_call then 
      tracker.log(f_name, f_args)
    end

    local result = {f(...)}

    if track_after_call then
      tracker.log(f_name, f_args)
    end

    return table.unpack(result)
  end
end

--! @brief Set hooks to track selected functions from the 'ntop' C API
function tracker.track_ntop()
  local fns = {
    "addUser",
    "deleteUser",
    "resetUserPassword",
    "runLiveExtraction",
    "dumpBinaryFile",
    "setPref",
  }

  for _, fn in pairs(fns) do
    if ntop[fn] and type(ntop[fn]) == "function" then
      ntop[fn] = tracker.hook(ntop[fn])
    end
  end
end

--! @brief Set hooks to track selected functions from the 'interface' C API
function tracker.track_interface()
  local fns = {
    "liveCapture",
  }

  for _, fn in pairs(fns) do
    if interface[fn] and type(interface[fn]) == "function" then
      interface[fn] = tracker.hook(interface[fn])
    end
  end
end

--! @brief Set a hook for a function defined in the provided table to track it, providing the function name
--! @param table is the table containing the function to track
--! @param fn is the name of the function to track
function tracker.track(table, fn)
  if table[fn] ~= nil and type(table[fn]) == "function" then 
    table[fn] = tracker.hook(table[fn], fn)
  else
    io.write("tracker: "..fn.." is not defined or not a function\n")
  end
end

-- #################################

return tracker

