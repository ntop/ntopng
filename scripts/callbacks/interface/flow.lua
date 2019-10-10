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

local function addL4Callaback(l4_proto, hook_name, script_key, callback)
   local l4_scripts = available_modules.l4_hooks[l4_proto]

   if(l4_scripts == nil) then
      l4_scripts = {}
      available_modules.l4_hooks[l4_proto] = l4_scripts
   end

   l4_scripts[hook_name] = l4_scripts[hook_name] or {}
   l4_scripts[hook_name][script_key] = callback
end

-- The function below is called once (#pragma once)
function setup()
   if do_trace then print("flow.lua:setup() called\n") end

   available_modules = user_scripts.load(user_scripts.script_types.flow, interface.getId(), "flow", nil, nil, do_benchmark)

   -- Reorganize the modules to optimize lookup by L4 protocol
   -- E.g. l4_hooks = {tcp -> {periodicUpdate -> {check_tcp_retr}}, other -> {protocolDetected -> {mud, score}}}
   available_modules.l4_hooks = {}

   for hook_name, hooks in pairs(available_modules.hooks) do
      -- available_modules.l4_hooks
      for script_key, callback in pairs(hooks) do
         local script = available_modules.modules[script_key]

         if(script.l4_proto ~= nil) then
            local l4_proto = l4_proto_to_id(script.l4_proto)

            if(l4_proto == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unknown l4_proto '%s' in module '%s', skipping", script.l4_proto, script_key))
            else
               addL4Callaback(l4_proto, hook_name, script_key, callback)
            end
         else
            -- No l4 filter is active for the specified module
            -- Attach the protocol to all the L4 protocols
            for _, l4_proto in pairs(l4_keys) do
               local l4_proto = l4_proto[3]

               if(l4_proto > 0) then
                  addL4Callaback(l4_proto, hook_name, script_key, callback)
               end
            end
         end
      end
   end
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
-- @param l4_filter the L4 protocol filter
-- @param mod_fn the callback to call
local function call_modules(l4_filter, mod_fn)
   local hooks = available_modules.l4_hooks[l4_filter]

   if(hooks ~= nil) then
      hooks = hooks[mod_fn]
   end

   if(hooks == nil) then
      if do_trace then print(string.format("No flow.lua modules, skipping %s(%d) for %s\n", mod_fn, l4_filter, shortFlowLabel(flow.getInfo()))) end
      return
   end

   -- TODO too expensive, remove
   local info = flow.getInfo()

   for mod_key, hook_fn in pairs(hooks) do
      if do_trace then print(string.format("%s() [check: %s]: %s\n", mod_fn, mod_key, shortFlowLabel(info))) end

      hook_fn({
        flow_info = info
      })
   end
end

-- #################################################################

-- Given an L4 protocol, we must call both the hooks registered for that protocol and
-- the hooks registered for any L4 protocol (id 255)
function protocolDetected(l4_proto)
   call_modules(l4_proto, "protocolDetected")
end

-- #################################################################

function statusChanged(l4_proto)
   call_modules(l4_proto, "statusChanged")
end

-- #################################################################

function flowEnd(l4_proto)
   call_modules(l4_proto, "flowEnd")
end

-- #################################################################

function periodicUpdate(l4_proto)
   call_modules(l4_proto, "periodicUpdate")
end
