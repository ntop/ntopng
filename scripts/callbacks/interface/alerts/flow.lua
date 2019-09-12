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
local check_modules = {protocolDetected = {}, statusChanged = {}, idle = {}, periodicUpdate = {}}

-- #################################################################

-- The function below is called once (#pragma once)
function setup()
  if do_trace then print("flow.lua:setup() called\n") end

  local available_modules = alerts_api.load_flow_check_modules()

  for modk, _module in pairs(available_modules) do
    if _module.setup then
      local is_enabled = _module.setup()

      if is_enabled then
	if _module.protocolDetected then check_modules["protocolDetected"][modk] = _module end
	if _module.statusChanged    then check_modules["statusChanged"][modk] = _module end
	if _module.idle             then check_modules["idle"][modk] = _module end
	if _module.periodicUpdate   then check_modules["periodicUpdate"][modk] = _module end
      end
    else
      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("%s module is missing the mandatory setup() function, it will be ignored", modk))
    end
  end
end

-- #################################################################

function protocolDetected()
  if table.empty(check_modules["protocolDetected"]) then
    if do_trace then print("No flow.lua modules, skipping protocolDetected()\n") end
    return
  end

  local info = flow.getInfo()

  if do_trace then print("protocolDetected(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules["protocolDetected"]) do
     _module.protocolDetected(info)
  end
end

-- #################################################################

function statusChanged()
  if table.empty(check_modules["statusChanged"]) then
    if do_trace then print("No flow.lua modules, skipping statusChanged()\n") end
    return
  end

  local info = flow.getInfo()

  if do_trace then print("statusChanged(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules["statusChanged"]) do
     _module.statusChanged(info)
  end
end

-- #################################################################

function idle()
  if table.empty(check_modules["idle"]) then
    if do_trace then print("No flow.lua modules, skipping idle()\n") end
    return
  end

  local info = flow.getInfo()

  if do_trace then print("idle(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules["idle"]) do
     _module.idle(info)
  end
end

-- #################################################################

function periodicUpdate()
  if table.empty(check_modules["periodicUpdate"]) then
    if do_trace then print("No flow.lua modules, skipping periodicUpdate()\n") end
    return
  end

  local info = flow.getInfo()

  if do_trace then print("periodicUpdate(): ".. shortFlowLabel(info) .. "\n") end

  for _, _module in pairs(check_modules["periodicUpdate"]) do
     _module.periodicUpdate(info)
  end
end
