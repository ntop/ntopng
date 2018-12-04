--
-- (C) 2017-18 - ntop.org
--

local json = require "dkjson"

local tracker = {}

function tracker.hook(f, name)
  return function(...)
    local f_name
    if name ~= nil then
      f_name = name
    else
      f_name = debug.getinfo(1, "n").name
    end

    if f_name ~= nil then
      local args_print = {}
      for k, v in pairs({...}) do
        args_print[k] = tostring(v)
      end

      local jobj = { 
        scope = 'function',
        name = f_name,
        params = args_print
      }

      local entity = alertEntity("user")
      local entity_value = _SESSION["user"]
      local alert_type = alertType("alert_user_activity")
      local alert_severity = alertSeverity("info")
      local alert_json = json.encode(jobj)

      local old_iface = interface.getStats().id
      interface.select(tostring(getFirstInterfaceId()))

      -- local fmt = string.format("%s(%s)\n", f_name, table.concat(args_print or {}, ", "))
      -- io.write(fmt)

      interface.storeAlert(entity, entity_value, alert_type, alert_severity, alert_json)

      interface.select(tostring(old_iface))
    end

    local result = {f(...)}

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
  table[fn] = tracker.hook(table[fn], fn)
end

-- #################################

return tracker

