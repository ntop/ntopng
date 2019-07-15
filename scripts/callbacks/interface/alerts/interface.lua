--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local do_trace      = false
local config_alerts = nil
local ifname        = nil
local available_modules = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if(do_trace) then print("alert.lua:setup("..str_granularity..") called\n") end
   ifname = interface.setActiveInterfaceId(tonumber(interface.getId()))
   config_alerts = getInterfaceConfiguredAlertThresholds(ifname, str_granularity)

   -- Load the threshold checking functions
   available_modules = alerts_api.load_check_modules("interface", str_granularity)
end

-- #################################################################

-- The function below is called once
function checkInterfaceAlerts(granularity)
   local info = interface.getStats()
   local ifid = interface.getId()
   local interface_key   = "iface_"..ifid
   local interface_config = config_alerts[interface_key] or {}
   local global_config = config_alerts["interfaces"] or {}
   local has_configured_alerts = (table.len(interface_config) or table.len(global_config))
   local entity_info = alerts_api.interfaceAlertEntity(ifid)

   if(do_trace) then print("checkInterfaceAlerts()\n") end

   if(has_configured_alerts) then
      for _, check in pairs(available_modules) do
        local config = interface_config[check.key] or global_config[check.key]

        if config then
           check.check_function({
              granularity = granularity,
              alert_entity = entity_info,
              entity_info = info,
              alert_config = config,
              check_module = check,
           })
        end
      end
   end

   for alert in pairs(interface.getExpiredAlerts(granularity2id(granularity))) do
      local alert_type, alert_subtype = alerts_api.triggerIdToAlertType(alert)

      if(do_trace) then print("Expired Alert@"..granularity..": ".. alert .." called\n") end

      alerts_api.new_release(entity_info, {
         alert_type = alert_consts.alert_types[alertTypeRaw(alert_type)],
         alert_subtype = alert_subtype,
         alert_granularity = alert_consts.alerts_granularities[granularity],
      })
   end
end
