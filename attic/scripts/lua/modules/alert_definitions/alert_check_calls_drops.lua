--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_check_calls_drops = classes.class(alert)

-- ##############################################

alert_check_calls_drops.meta = {
  alert_key = other_alert_keys.alert_check_calls_drops,
  i18n_title = "alerts_dashboard.checks_calls_drops",
  icon = "fas fa-fw fa-tint",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_check_calls_drops:init(drops)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    drops = drops
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_check_calls_drops.format(ifid, alert, alert_type_params)
  if(alert.alert_subtype == "flow") then
    return(i18n("alerts_dashboard.flow_checks_calls_drops_description", {
      num_drops = alert_type_params.drops,
      url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=callbacks&tab=flows&ifid=" .. string.format("%d", ifid),
    }))
  end

  return("")
end

-- #######################################################

return alert_check_calls_drops
