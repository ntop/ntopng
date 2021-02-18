--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local json = require("dkjson")
local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_remote_to_remote = classes.class(alert)

-- ##############################################

alert_remote_to_remote.meta = {
   status_key = status_keys.ntopng.status_remote_to_remote,
   alert_key = alert_keys.ntopng.alert_remote_to_remote,
   i18n_title = "alerts_dashboard.remote_to_remote",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_remote_to_remote:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
   }
end

-- #######################################################

function alert_remote_to_remote.format(ifid, alert, alert_type_params)
   return i18n("alerts_dashboard.remote_to_remote")
end

-- #######################################################

return alert_remote_to_remote
