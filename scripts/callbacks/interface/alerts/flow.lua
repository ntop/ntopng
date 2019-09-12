--
-- (C) 2019 - ntop.org
--
-- The functions below are called with a LuaC "flow" context set.
-- See alerts_api.load_flow_check_modules documentation for information
-- on adding custom scripts.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local alerts_api = require("alerts_api")

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

local do_trace = false
local check_modules = {}

-- #################################################################

-- The function below is called once (#pragma once)
function setup()
  if(do_trace) then print("flow.lua:setup() called\n") end

  local available_modules = alerts_api.load_flow_check_modules()
  check_modules = {}

  for modk, _module in pairs(available_modules) do
    if _module.setup then
      local is_enabled = _module.setup()

      if(is_enabled) then
        check_modules[modk] = _module
      end
    else
      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("%s module is missing the mandatory setup() function, it will be ignored", modk))
    end
  end
end

-- #################################################################

function protocolDetected()
  if(table.empty(check_modules)) then
    if(do_trace) then print("No flow.lua modules, skipping protocolDetected()\n") end
    return
  end

  local info = flow.getInfo()

  if(do_trace) then print("protocolDetected(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules) do
    if _module.protocolDetected then
      _module.protocolDetected(info)
    end
  end
end

-- #################################################################

function statusChanged()
  if(table.empty(check_modules)) then
    if(do_trace) then print("No flow.lua modules, skipping statusChanged()\n") end
    return
  end

  local info = flow.getInfo()

  if(do_trace) then print("statusChanged(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules) do
    if _module.statusChanged then
      _module.statusChanged(info)
    end
  end
end

-- #################################################################

function idle()
  if(table.empty(check_modules)) then
    if(do_trace) then print("No flow.lua modules, skipping idle()\n") end
    return
  end

  local info = flow.getInfo()

  if(do_trace) then print("idle(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules) do
    if _module.idle then
      _module.idle(info)
    end
  end
end


-- #################################################################

function periodicUpdate()
  if(table.empty(check_modules)) then
    if(do_trace) then print("No flow.lua modules, skipping periodicUpdate()\n") end
    return
  end

  local info = flow.getInfo()

  if(do_trace) then print("periodicUpdate(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules) do
    if _module.periodicUpdate then
      _module.periodicUpdate(info)
    end
  end
end
