--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local alert_utils = require "alert_utils"

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")
local host_pools = require "host_pools"

local do_benchmark = false         -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

-- DEBUG: benchmarks local to the execution of this script
-- Will be removed once all the host.<method> calls will be performed
-- inside the custom scripts
local do_script_benchmark = false
local script_benchmark_begin_time
local script_benchmark_tot_clock = 0
local script_benchmark_tot_calls = 0

local available_modules = nil
local confisets = nil
local ifid = nil
local ts_enabled = nil
local host_entity = alert_consts.alert_entities.host.entity_id
local pools_instance = nil

-- #################################################################

local function benchmark_begin()
   if do_benchmark then
      script_benchmark_begin_time = os.clock()
   end
end

-- #################################################################

local function benchmark_end()
   if do_benchmark then
      script_benchmark_tot_clock = script_benchmark_tot_clock + os.clock() - script_benchmark_begin_time
      script_benchmark_tot_calls = script_benchmark_tot_calls + 1
   end
end

-- #################################################################

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   ifid = interface.getId()
   local ifname = interface.setActiveInterfaceId(ifid)

   if(do_trace) then print("["..ifname.."] alert.lua:setup("..str_granularity..") called [deadline: "..formatEpoch(ntop.getDeadline()).."]\n") end

   -- Load the threshold checking functions
   available_modules = user_scripts.load(ifid, user_scripts.script_types.traffic_element, "host", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })

   configsets = user_scripts.getConfigsets()
   pools_instance = host_pools:create()
   ts_enabled = areHostTimeseriesEnabled()
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("["..getInterfaceName(ifid).."] alert.lua:teardown("..str_granularity..") called [deadline: "..formatEpoch(ntop.getDeadline()).."]\n") end

   if do_script_benchmark and script_benchmark_tot_calls > 0 then
      traceError(TRACE_NORMAL,TRACE_CONSOLE, string.format("[tot_elapsed: %.4f][tot_num_calls: %u][avg time per call: %.4f]",
      							   script_benchmark_tot_clock,
							   script_benchmark_tot_calls,
							   script_benchmark_tot_clock / script_benchmark_tot_calls))
   end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

local function in_time()
   -- Read the deadline stored in the lua engine and, if the deadline is
   -- too close, consider not time left for the script.
   -- Calling os.time() every time is not expensive, see method in_time() inside flow.lua
   -- for measurements.
   if ntop.getDeadline() == 0 then
      if do_trace then
	 print("No deadline set, always in time")
      end

      return true -- No deadline, always in time
   end

   local time_left = ntop.getDeadline() - os.time()
   local res = time_left > 1

   if do_trace then
      if not res then
	 print(">>> No time left, [deadline: "..formatEpoch(ntop.getDeadline()).."]\n")
      else
	 print("Enough time left [deadline: "..formatEpoch(ntop.getDeadline()).."]\n")
      end
   end

   return res
end

-- #################################################################

-- The function below is called once per host
function runScripts(granularity)
   if table.empty(available_modules.hooks[granularity]) then
      if(do_trace) then print("host:runScripts("..granularity.."): no modules, skipping\n") end
      return
   end

   local host_ip = host.getIp()
   local pool_id = host.getPoolId()["host_pool_id"]
   local host_key   = hostinfo2hostkey({ip = host_ip.ip, vlan = host_ip.vlan}, nil, true --[[ force @[vlan] even when vlan is 0 --]])
   local granularity_id = alert_consts.alerts_granularities[granularity].granularity_id

   benchmark_begin()
   local cur_alerts = host.getAlerts(granularity_id)
   local is_localhost = host.isLocal()
   benchmark_end()

   local entity_info = alerts_api.hostAlertEntity(host_ip.ip, host_ip.vlan)

   if in_time() then
      -- Fetch the actual configset id using the host pool
      local confset_id = pools_instance:get_configset_id_by_pool_id(pool_id)
      -- Retrieve the configuration associated to the confset_id
      local host_conf = user_scripts.getConfigById(configsets, confset_id, "host")
      local when = os.time()

      for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
	 local user_script = available_modules.modules[mod_key]
	 local conf = user_scripts.getTargetHookConfig(host_conf, user_script, granularity)

	 if(conf.enabled) then
	    alerts_api.invokeScriptHook(user_script, confset_id, hook_fn, {
					   granularity = granularity,
					   alert_entity = entity_info,
					   entity_info = host_ip,
					   cur_alerts = cur_alerts,
					   user_script_config = conf.script_conf,
					   user_script = user_script,
					   when = when,
					   ifid = ifid,
					   ts_enabled = ts_enabled,
	    })
	 end
      end
   end

   -- cur_alerts now contains unprocessed triggered alerts, that is,
   -- those alerts triggered but then disabled or unconfigured (e.g., when
   -- the user removes a threshold from the gui)
   if #cur_alerts > 0 then
      alerts_api.releaseEntityAlerts(entity_info, cur_alerts)
   end
end

-- #################################################################

function releaseAlerts(granularity)
  local host_ip = host.getIp()
  local entity_info = alerts_api.hostAlertEntity(host_ip.ip, host_ip.vlan)

  alerts_api.releaseEntityAlerts(entity_info, host.getAlerts(granularity))
end
