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

local function call_modules(mod_fn)
   if table.empty(check_modules[mod_fn]) then
      if do_trace then print(string.format("No flow.lua modules, skipping %s()\n", mod_fn)) end
      return
   end

   local info = flow.getInfo()

   if do_trace then print(string.format("%s(): %s\n", mod_fn, shortFlowLabel(info))) end

   for _, _module in pairs(check_modules[mod_fn]) do
      _module[mod_fn](info)
   end

end

-- #################################################################

function protocolDetected()
   return call_modules("protocolDetected")
end

-- #################################################################

function statusChanged()
   return call_modules("statusChanged")
end

-- #################################################################

function idle()
   return call_modules("idle")
end

-- #################################################################

function periodicUpdate()
   return call_modules("periodicUpdate")
end
