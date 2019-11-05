--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

local do_benchmark = true          -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local config_alerts = nil
local ifid = nil
local available_modules = nil
local interface_entity = alert_consts.alert_entities.interface.entity_id

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if(do_trace) then print("alert.lua:setup("..str_granularity..") called\n") end
   ifid = interface.getId()
   local ifname = interface.setActiveInterfaceId(ifid)

   -- Load the check modules
   available_modules = user_scripts.load(user_scripts.script_types.traffic_element, ifid, "interface", str_granularity, nil, do_benchmark)

   config_alerts = getInterfaceConfiguredAlertThresholds(ifname, str_granularity, available_modules.modules)
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

-- The function below is called once
function checkAlerts(granularity)
   if table.empty(available_modules.hooks[granularity]) then
      if(do_trace) then print("interface:checkAlerts("..granularity.."): no modules, skipping\n") end
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
   local interface_config = config_alerts[interface_key] or {}
   local global_config = config_alerts["interfaces"] or {}
   local has_configuration = (table.len(interface_config) or table.len(global_config))
   local entity_info = alerts_api.interfaceAlertEntity(ifid)

   if(do_trace) then print("checkInterfaceAlerts()\n") end

   if(has_configuration) then
      for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
        local check = available_modules.modules[mod_key]
        local config = interface_config[check.key] or global_config[check.key]
        local do_call

        if(check.is_alert) then
          -- Alert modules are only called if there is a configuration defined or always_enabled is set
          do_call = ((not suppressed_alerts) and (config or check.always_enabled))
        else
          -- always call non alert scripts. available_modules does not contain scripts disabled by the user
          do_call = true
        end

        if(do_call) then
           hook_fn({
              granularity = granularity,
              alert_entity = entity_info,
              entity_info = info,
	      cur_alerts = cur_alerts,
              alert_config = config,
              user_script = check,
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
