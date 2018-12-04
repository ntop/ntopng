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

      -- TODO push alert
      -- local fmt = string.format("%s(%s)\n", f_name, table.concat(args_print or {}, ", "))
      -- io.write(fmt)
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

