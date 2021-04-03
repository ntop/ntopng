--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_unexpected_smtp_server = classes.class(alert)

-- ##############################################

alert_unexpected_smtp_server.meta = {
   alert_key = flow_alert_keys.flow_alert_unexpected_smtp_server,
   i18n_title = "unexpected_smtp.alert_unexpected_smtp_title",
   icon = "fas fa-exclamation",
   has_victim = true,
   has_attacker = true,
}

-- ##############################################

function alert_unexpected_smtp_server:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_unexpected_smtp_server.format(ifid, alert, alert_type_params)
    return(i18n("unexpected_smtp.status_unexpected_smtp_description", { server=alert_type_params.server_ip} ))
end

-- #######################################################

return alert_unexpected_smtp_server
