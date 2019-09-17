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

local do_benchmark = false
local do_trace = false

local check_modules = {}
local benchmarks = {}

-- #################################################################

local function benchmark_begin(mod_fn, mod_key)
   if not do_benchmark then return end

   if not benchmarks[mod_fn] then
      benchmarks[mod_fn] = {}
   end

   if not benchmarks[mod_fn][mod_key] then
      benchmarks[mod_fn][mod_key] = {num = 0, elapsed = 0}
   end

   benchmarks[mod_fn][mod_key]["begin"] = os.clock()

   -- print(string.format("begin: %.4f\n", benchmarks[mod_fn][mod_key]["begin"]))
end

-- #################################################################

local function benchmark_end(mod_fn, mod_key)
   if not do_benchmark then return end

   if benchmarks[mod_fn] and benchmarks[mod_fn][mod_key] then
      local bend = os.clock()
      local latest_elapsed = bend - benchmarks[mod_fn][mod_key]["begin"]
      -- print(string.format("end: %.2f\n", bend))

      benchmarks[mod_fn][mod_key]["elapsed"] = benchmarks[mod_fn][mod_key]["elapsed"] + latest_elapsed
      benchmarks[mod_fn][mod_key]["num"] = benchmarks[mod_fn][mod_key]["num"] + 1
   end
end

-- #################################################################

local function print_benchmark()
   if do_benchmark then
      for mod_fn, modules in pairs(benchmarks) do
	 for mod_k, mod_benchmark in pairs(modules) do
	    print(string.format("%s() [check: %s][elapsed: %.4f][num: %u][avg: %.4f]\n",
				mod_fn, mod_k, mod_benchmark["elapsed"], mod_benchmark["num"],
				mod_benchmark["elapsed"] / mod_benchmark["num"]))
	 end
      end
   end
end

-- #################################################################

-- The function below is called once (#pragma once)
function setup()
  if do_trace then print("flow.lua:setup() called\n") end

  check_modules = alerts_api.load_flow_check_modules(true --[[ only enabled modules --]])
end

-- #################################################################

-- The function below is called once (#pragma once) right before
-- the lua virtual machine is destroyed
function teardown()
   if do_trace then print("flow.lua:teardown() called\n") end
   if do_benchmark then print_benchmark() end
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

      benchmark_begin(mod_fn, _module.key)
      _module[mod_fn](info)
      benchmark_end(mod_fn, _module.key)
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
