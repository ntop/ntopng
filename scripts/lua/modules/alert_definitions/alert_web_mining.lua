--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_web_mining = classes.class(alert)

-- ##############################################

alert_web_mining.meta = {
   status_key = status_keys.ntopng.status_web_mining_detected,
   alert_key = alert_keys.ntopng.alert_web_mining,
   i18n_title = "alerts_dashboard.web_mining",
   icon = "fab fa-bitcoin",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_web_mining:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {}
end

-- #######################################################

function alert_web_mining.format(ifid, alert, alert_type_params)
   
end

-- #######################################################

return alert_web_mining


--
-- (C) 2019-20 - ntop.