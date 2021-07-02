--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local json = require "dkjson"

-- ##############################################

local alert_lateral_movement = classes.class(alert)

-- ##############################################

alert_lateral_movement.meta = {
   alert_key = flow_alert_keys.flow_alert_lateral_movement,
   i18n_title = "alerts_dashboard.lateral_movement",
   icon = "fas fa-fw fa-arrows-alt-h",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_lateral_movement:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_lateral_movement.format(ifid, alert, alert_type_params)
   -- Extracting info field
   local info = ""
   local href = ""

   if alert.json then
      info = json.decode(alert["json"])
      if not isEmptyString(info["info"]) then
         info = "[" .. info["info"] .. "]"
      else
         info = ""
      end   
   end

   if ntop.isAdministrator() then
      href = '<a href="/lua/pro/enterprise/service_map.lua"><i class="fas fa-lg fa-concierge-bell"></i></a>'
   end

   return(i18n("alerts_dashboard.lateral_movement_descr", { info = info, href = href }))
end

-- #######################################################

return alert_lateral_movement
