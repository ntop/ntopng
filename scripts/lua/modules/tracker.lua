--
-- (C) 2017-18 - ntop.org
--

local json = require "dkjson"

local tracker = {}

function tracker.log(f_name, f_args)
  local jobj = { 
    scope = 'function',
    name = f_name,
    params = f_args
  }

  local entity = alertEntity("user")
  local entity_value = ternary(_SESSION["user"] ~= nil, _SESSION["user"], 'system')
  local alert_type = alertType("alert_user_activity")
  local alert_severity = alertSeverity("info")
  local alert_json = json.encode(jobj)

  -- tprint(alert_json)

  local old_iface = interface.getStats().id
  local sys_iface = getFirstInterfaceId()
  interface.select(tostring(sys_iface))

  interface.storeAlert(entity, entity_value, alert_type, alert_severity, alert_json)

  interface.select(tostring(old_iface))
end

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

    local result = {f(...)}

    if f_name ~= nil then
      tracker.log(f_name, f_args)
    end

    return table.unpack(result)
  end
end

function tracker.track_ntop()
  local fns = {
    "addUser",
    "deleteUser",
    "resetUserPassword",
    "runLiveExtraction",
    "dumpBinaryFile",
    --"setPref",
  }

  for _, fn in pairs(fns) do
    if ntop[fn] and type(ntop[fn]) == "function" then
      ntop[fn] = tracker.hook(ntop[fn])
    end
  end
end

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

function tracker.track(table, fn)
  if table[fn] ~= nil and type(table[fn]) == "function" then 
    table[fn] = tracker.hook(table[fn], fn)
  else
    io.write("tracker: "..fn.." is not defined or not a function\n")
  end
end

-- #################################

return tracker

