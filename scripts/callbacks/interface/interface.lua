--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
require "lua_utils"
local alert_utils = require "alert_utils"
local interface_pools = require "interface_pools"

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

local do_benchmark = true          -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local ifid = nil
local available_modules = nil
local interface_entity = alert_consts.alert_entities.interface.entity_id
local iface_config = nil
local confset_id = nil
local pools_instance = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if(do_trace) then print("alert.lua:setup("..str_granularity..") called\n") end
   ifid = interface.getId()
   local ifname = interface.setActiveInterfaceId(ifid)

   -- Load the check modules
   available_modules = user_scripts.load(ifid, user_scripts.script_types.traffic_element, "interface", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })

   local configsets = user_scripts.getConfigsets()
   -- Instance of local network pools to get assigned members
   pools_instance = interface_pools:create()
   -- Retrieve the confset_id (possibly) associated to this interface
   confset_id = pools_instance:get_configset_id(string.format("%d", ifid))
   -- Retrieve the configuration associated to the confset_id
   iface_config = user_scripts.getConfigById(configsets, confset_id, "interface")
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
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
   local suppressed_alerts = alerts_api.hasSuppressedAlerts(ifid, interface_entity, interface_key)

   if suppressed_alerts then
      releaseAlerts(granularity_id)
   end

   local info = interface.getStats()
   local cur_alerts = interface.getAlerts(granularity_id)
   local entity_info = alerts_api.interfaceAlertEntity(ifid)

   if(do_trace) then print("checkInterfaceAlerts()\n") end

   for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
     local user_script = available_modules.modules[mod_key]
     local conf = user_scripts.getTargetHookConfig(iface_config, user_script, granularity)

     if(conf.enabled) then
        if((not user_script.is_alert) or (not suppressed_alerts)) then
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
