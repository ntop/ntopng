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

local do_benchmark = true         -- Compute benchmarks and store their results
local do_print_benchmark = true  -- Print benchmarks results to standard output
local do_trace = false            -- Trace lua calls

local check_modules = {}
local benchmarks = {}

-- #################################################################

-- This function is called, for each module and for each callback
-- right before the actual callback call.
-- Benchmarks are stored in a lua table `benchmarks` which which contains
-- module names as keys and other tables as values. Each table contains
-- callback names as keys and another table as value. Example:
--
-- table
-- mud table
-- mud.protocolDetected table
-- mud.protocolDetected.elapsed number 0.00012199999991935
-- mud.protocolDetected.num number 2
-- mud.protocolDetected.begin number 1865.756381
--
-- In the example above:
-- `mud` is the module name
-- `protocolDetected` is the callback found inside script `mud.lua` which has been executed
-- `elapsed` is the sum of the time taken during each execution of `protocolDetected`
-- `num` is the number of times the callback has been executed
-- `begin` is just the os.clock() value computed during the call of `benchmark_begin` and used
--      by `benchmark_end` to compute the difference which will be added to `elapsed`
local function benchmark_begin(mod_fn, mod_key)
   if not do_benchmark then return end

   if not benchmarks[mod_key] then
      benchmarks[mod_key] = {}
   end

   if not benchmarks[mod_key][mod_fn] then
      benchmarks[mod_key][mod_fn] = {num = 0, elapsed = 0}
   end

   benchmarks[mod_key][mod_fn]["begin"] = os.clock()
end

-- #################################################################

-- This function is called, for each module and for each callback,
-- right after the actual callback.
-- It computes the delta between the os.clock() computed by `benchmark_begin` and
-- and the current os.clock() to determine the time, in milliseconds, it took for
-- a particular callback to execute.
-- Also the number of executed callbacks is counted so statistics such as the average
-- time per-callback can be computed.
local function benchmark_end(mod_fn, mod_key)
   if not do_benchmark then return end

   if benchmarks[mod_key] and benchmarks[mod_key][mod_fn] then
      local bend = os.clock()
      local latest_elapsed = bend - benchmarks[mod_key][mod_fn]["begin"]

      benchmarks[mod_key][mod_fn]["elapsed"] = benchmarks[mod_key][mod_fn]["elapsed"] + latest_elapsed
      benchmarks[mod_key][mod_fn]["num"] = benchmarks[mod_key][mod_fn]["num"] + 1
   end
end

-- #################################################################

-- This function is just a wrapper to store the results of the benchmarks.
local function store_benchmark()
   if do_benchmark then
      alerts_api.store_flow_check_modules_benchmarks(benchmarks)
   end
end

-- #################################################################

-- This function outputs the results of the benchmark to std output.
local function print_benchmark()
   if do_benchmark and do_print_benchmark then
      for mod_k, modules in pairs(benchmarks) do
	 for mod_fn, mod_benchmark in pairs(modules) do
	    traceError(TRACE_NORMAL,TRACE_CONSOLE,
		       string.format("%s() [check: %s][elapsed: %.2f][num: %u][avg: %.2f]\n",
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

   -- Retrieve a table which maps method names to their corresponding ids
   -- e.g.,
   -- getTuple number 0
   -- getClientCountry number 3
   -- getServerIp number 2
   -- getServerCountry number 4
   -- getClientIp number 1
   local method_names_to_ids = flow.methodNamesToIds()

   -- Save the current flow metatable, which is the one populated
   -- from C upon VM creation
   local cur_metatable = getmetatable(flow)

   -- Implement a new metatable function which first tries to
   -- call methods populated by C and then, if no method is found,
   -- rather than giving up it tries to see if there is a method
   -- available in method_names_to_ids. In such case, the method
   -- is returned (wrapped in a function) so it is ready to be called
   local metatable_fn = function(t, k)
      local existing = cur_metatable.__index[k]
      if existing then
	 return existing
      end

      local method_id = method_names_to_ids[k]
      if method_id then
	 return function(...)
	    return flow.callMethodById(method_id, ...)
	 end
      end
   end

   -- Set the new metatable to the flow
   setmetatable(flow, {__index = metatable_fn})

   -- Now that the metatable is in place, we can load all the custom
   -- flow check modules
   check_modules = alerts_api.load_flow_check_modules(true --[[ only enabled modules --]])
end

-- #################################################################

-- The function below is called once (#pragma once) right before
-- the lua virtual machine is destroyed
function teardown()
   if do_trace then
      print("flow.lua:teardown() called\n")
   end

   if do_benchmark then
      -- If the benchmark is enabled, it's time to store it
      store_benchmark()

      if do_print_benchmark then
	 -- Possibly print it to stdout
	 print_benchmark()
      end
   end
end

-- #################################################################

-- Function for the actual module execution. Iterates over available (and enabled)
-- modules, calling them one after one.
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
