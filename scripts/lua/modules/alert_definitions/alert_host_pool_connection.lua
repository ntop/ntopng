--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_host_pool_connection = classes.class(alert)

-- ##############################################

alert_host_pool_connection.meta = {
  alert_key = alert_keys.ntopng.alert_host_pool_connection,
  i18n_title = "alerts_dashboard.host_pool_connection",
  icon = "fas fa-sign-in",
}

-- ##############################################

function alert_host_pool_connection:init(pool)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = alert_creators.createPoolConnectionDisconnection(pool)
end

-- #######################################################

function alert_host_pool_connection.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.host_pool_has_connected", {
    pool = alert_type_params.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return alert_host_pool_connection
