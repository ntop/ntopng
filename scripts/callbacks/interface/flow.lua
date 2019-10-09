--
-- (C) 2019 - ntop.org
--
-- The functions below are called with a LuaC "flow" context set.
-- See user_scripts.load() documentation for information
-- on adding custom scripts.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local user_scripts = require("user_scripts")

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

local do_benchmark = true          -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local available_modules = nil
local benchmarks = {}

-- #################################################################

-- The function below is called once (#pragma once)
function setup()
   if do_trace then print("flow.lua:setup() called\n") end

   available_modules = user_scripts.load(user_scripts.script_types.flow, interface.getId(), "flow", nil, nil, do_benchmark)
end

-- #################################################################

-- The function below is called once (#pragma once) right before
-- the lua virtual machine is destroyed
function teardown()
   if do_trace then
      print("flow.lua:teardown() called\n")
   end

   if do_benchmark then
      user_scripts.benchmark_dump(do_print_benchmark)
   end
end

-- #################################################################

-- Function for the actual module execution. Iterates over available (and enabled)
-- modules, calling them one after one.
local function call_modules(mod_fn)
   if table.empty(available_modules.hooks[mod_fn]) then
      if do_trace then print(string.format("No flow.lua modules, skipping %s() for %s\n", mod_fn, shortFlowLabel(flow.getInfo()))) end
      return
   end

   local info = flow.getInfo()

   for mod_key, hook_fn in pairs(available_modules.hooks[mod_fn]) do
      if do_trace then print(string.format("%s() [check: %s]: %s\n", mod_fn, mod_key, shortFlowLabel(info))) end

      hook_fn({
        flow_info = info
      })
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

function flowEnd()
   return call_modules("flowEnd")
end

-- #################################################################

function periodicUpdate()
   return call_modules("periodicUpdate")
end
