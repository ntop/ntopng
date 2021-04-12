--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_remote_access = classes.class(alert)

-- ##############################################

alert_remote_access.meta = {
   alert_key  = flow_alert_keys.flow_alert_remote_access,
   i18n_title = "remote_access.alert.title",
   icon = "fas fa-info",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_remote_access:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_remote_access.format(ifid, alert, alert_type_params)
   local time = alert_type_params["last_seen"] - alert_type_params["first_seen"]

   if time == 0 then
      time = "< 1"
   end

   return (i18n("remote_access.alert.description", { sec = time }))
end

-- #######################################################

return alert_remote_access
