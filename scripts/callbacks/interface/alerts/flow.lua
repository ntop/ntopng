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
  if do_trace then print("flow.lua:setup() called\n") end

  check_modules = alerts_api.load_flow_check_modules(true --[[ only enabled modules --]])
end

-- #################################################################

local function call_modules(mod_fn)
   if table.empty(check_modules[mod_fn]) then
      if do_trace then print(string.format("No flow.lua modules, skipping %s() for %s\n", mod_fn, shortFlowLabel(flow.getInfo()))) end
      return
   end

   local info = flow.getInfo()

   for _, _module in pairs(check_modules[mod_fn]) do
      if do_trace then print(string.format("%s() [check: %s]: %s\n", mod_fn, _module.key, shortFlowLabel(info))) end
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
