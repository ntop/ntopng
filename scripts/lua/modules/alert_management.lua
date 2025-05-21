--
-- (C) 2013-24 - ntop.org
--
-- This module should manage the alerts, like releasing alerts, triggering ecc.

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alert_consts = require "alert_consts"

-- ##############################################

local alert_management = {}

-- ##############################################

local function alertLookup(alerts, alert)
   for _, a in ipairs(alerts) do
      if a.rowid == alert.rowid then
         return a
      end
   end

   return nil
end

-- Convenient method to release multiple alerts on an entity
function alert_management.releaseEntityAlerts(entity_info, pre_alerts)
   local engaged_alerts = interface.getEngagedAlerts(entity_info.alert_entity.entity_id, entity_info.entity_val)

   for _, cur_alert in ipairs(engaged_alerts) do
      -- NOTE: do not pass alerts here as a parameters as deleting items while
      -- does not work in lua

      if alertLookup(pre_alerts, cur_alert) then
         -- This alert has to be released (not re-triggered)

         local cur_alert_type = alert_consts.alert_types[alert_consts.getAlertType(cur_alert.alert_id)]
         -- Instantiate the alert.
         -- NOTE: No parameter is passed to :new() as parameters are NOT used when releasing alerts
         -- This may change in the future.
         local cur_alert_instance = cur_alert_type:new( --[[ empty, no parameters for the release --]])

         -- Set alert params.
         cur_alert_instance:set_score(cur_alert.score)
         cur_alert_instance:set_subtype(cur_alert.subtype)
         cur_alert_instance:set_granularity(alert_consts.sec2granularity(cur_alert.granularity))
         local entity = entity_info
         if (entity_info == nil) then
            entity = {
               alert_entity = alert_consts.alertEntityById(cur_alert.entity_id),
               entity_val = cur_alert.entity_val
            }
         end

         cur_alert_instance:release(entity)
      end
   end
end

return alert_management
