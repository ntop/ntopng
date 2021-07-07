--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local other_alert_keys = require "other_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_dropped_alerts = classes.class(alert)

alert_dropped_alerts.meta = {
  alert_key = other_alert_keys.alert_dropped_alerts,
  i18n_title = i18n("show_alerts.dropped_alerts"),
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.system,
     alert_entities.interface,
  },
}

-- ##############################################

function alert_dropped_alerts:init(ifid, num_dropped)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      ifid = ifid,
      num_dropped = num_dropped,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_dropped_alerts.format(ifid, alert, alert_type_params)
   return(i18n("alert_messages.iface_alerts_dropped", {
    iface = getHumanReadableInterfaceName(alert_type_params.ifid),
    num_dropped = alert_type_params.num_dropped,
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. alert_type_params.ifid
  }))
end

-- #######################################################

return alert_dropped_alerts
