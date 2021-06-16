--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
require "lua_utils"
local alert_utils = require "alert_utils"
local interface_pools = require "interface_pools"

local alerts_api = require("alerts_api")
local checks = require("checks")
local alert_consts = require("alert_consts")

local do_benchmark = false         -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local ifid = nil
local available_modules = nil
local interface_entity = alert_consts.alert_entities.interface.entity_id
local iface_config = nil
local configset = nil
local pools_instance = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if(do_trace) then print("alert.lua:setup("..str_granularity..") called\n") end
   ifid = interface.getId()
   local ifname = interface.setActiveInterfaceId(ifid)

   -- Load the check modules
   available_modules = checks.load(ifid, checks.script_types.traffic_element, "interface", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })

   configset = checks.getConfigset()
   -- Instance of local network pools to get assigned members
   pools_instance = interface_pools:create()
   -- Retrieve the configuration associated to the confset
   iface_config = checks.getConfig(configset, "interface")
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   checks.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

-- The function below is called once
function runScripts(granularity)
   if table.empty(available_modules.hooks[granularity]) then
      if(do_trace) then print("interface:runScripts("..granularity.."): no modules, skipping\n") end
      return
   end

   local granularity_id = alert_consts.alerts_granularities[granularity].granularity_id
   local interface_key   = "iface_"..ifid

   local info = interface.getStats()
   local cur_alerts = interface.getAlerts(granularity_id)
   local entity_info = alerts_api.interfaceAlertEntity(ifid)

   if(do_trace) then print("checkInterfaceAlerts()\n") end

   for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
     local check = available_modules.modules[mod_key]
     local conf = checks.getTargetHookConfig(iface_config, check, granularity)

     if(conf.enabled) then
	alerts_api.invokeScriptHook(check, configset, hook_fn, {
				       granularity = granularity,
				       alert_entity = entity_info,
				       entity_info = info,
				       cur_alerts = cur_alerts,
				       check_config = conf.script_conf,
				       check = check,
	})
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
  local ifid = interface.getId()
  local entity_info = alerts_api.interfaceAlertEntity(ifid)

  alerts_api.releaseEntityAlerts(entity_info, interface.getAlerts(granularity))
end
