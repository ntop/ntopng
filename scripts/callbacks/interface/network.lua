--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
require "lua_utils"
local alert_utils = require "alert_utils"
local local_network_pools = require "local_network_pools"


local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

local do_benchmark = false         -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local available_modules = nil
local ifid = nil
local network_entity = alert_consts.alert_entities.network.entity_id
local configsets = nil
local pools_instance = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end
   ifid = interface.getId()
   local ifname = interface.setActiveInterfaceId(ifid)

   -- Load the threshold checking functions
   available_modules = user_scripts.load(ifid, user_scripts.script_types.traffic_element, "network", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })

   configsets = user_scripts.getConfigsets()
   -- Instance of local network pools to get assigned members
   pools_instance = local_network_pools:create()
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

-- The function below is called once per local network
function runScripts(granularity)
   if table.empty(available_modules.hooks[granularity]) then
      if(do_trace) then print("network:runScripts("..granularity.."): no modules, skipping\n") end
      return
   end

   local info = network.getNetworkStats()
   local network_key = info and info.network_key
   if not network_key then return end

   local granularity_id = alert_consts.alerts_granularities[granularity].granularity_id

   local cur_alerts = network.getAlerts(granularity_id)
   local entity_info = alerts_api.networkAlertEntity(network_key)

   -- Retrieve the configset_id (possibly) associated to this network
   local confset_id = pools_instance:get_configset_id(network_key)
   -- Retrieve the configuration associated to the confset_id
   local subnet_conf = user_scripts.getConfigById(configsets, confset_id, "network")

   for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
      local user_script = available_modules.modules[mod_key]
      local conf = user_scripts.getTargetHookConfig(subnet_conf, user_script, granularity)

      if(conf.enabled) then
	 alerts_api.invokeScriptHook(user_script, confset_id, hook_fn, {
					granularity = granularity,
					alert_entity = entity_info,
					entity_info = info,
					cur_alerts = cur_alerts,
					user_script_config = conf.script_conf,
					user_script = user_script,
	 })
      end
   end

  -- cur_alerts contains unprocessed triggered alerts, that is,
  -- those alerts triggered but then disabled or unconfigured (e.g., when
  -- the user removes a threshold from the gui)
  if #cur_alerts > 0 then
     alerts_api.releaseEntityAlerts(entity_info, cur_alerts)
  end
end

-- #################################################################

function releaseAlerts(granularity)
  local info = network.getNetworkStats()
  local network_key = info and info.network_key
  if not network_key then return end

  local entity_info = alerts_api.networkAlertEntity(network_key)

  alerts_api.releaseEntityAlerts(entity_info, network.getAlerts(granularity))
end
