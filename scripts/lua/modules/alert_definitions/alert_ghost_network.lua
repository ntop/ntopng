--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_ghost_network = classes.class(alert)

-- ##############################################

alert_ghost_network.meta = {
  alert_key = alert_keys.ntopng.alert_ghost_network,
  i18n_title = "alerts_dashboard.ghost_network_detected",
  icon = "fas fa-ghost",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_ghost_network:init()
   -- Call the paren constructor
   self.super:init()

   self.alert_type_params = {}
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_ghost_network.format(ifid, alert, alert_type_params)
  return(i18n("alerts_dashboard.ghost_network_detected_description", {
    network = alert.alert_subtype,
    entity = getInterfaceName(ifid),
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=".. ifid .."&page=networks",
  }))
end

-- #######################################################

return alert_ghost_network
