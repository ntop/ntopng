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

local alert_unexpected_smtp_server = classes.class(alert)

-- ##############################################

alert_unexpected_smtp_server.meta = {
   status_key = status_keys.ntopng.status_unexpected_smtp_server,
   alert_key = alert_keys.ntopng.alert_unexpected_smtp_server,
   i18n_title = "unexpected_smtp.alert_unexpected_smtp_title",
   icon = "fas fa-exclamation",
}

-- ##############################################

function alert_unexpected_smtp_server:init(client_ip, server_ip)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    client_ip = client_ip,
    server_ip = server_ip
   }
end

-- #######################################################

function alert_unexpected_smtp_server.format(ifid, alert, alert_type_params)
    return(i18n("unexpected_smtp.status_unexpected_smtp_description", { server=alert_type_params.server_ip} ))
end

-- #######################################################

return alert_unexpected_smtp_server
