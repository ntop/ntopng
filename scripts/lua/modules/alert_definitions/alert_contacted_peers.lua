--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local format_utils = require("format_utils")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_contacted_peers = classes.class(alert)

-- ##############################################

alert_contacted_peers.meta = {
   alert_key = alert_keys.ntopng.alert_contacted_peers,
   i18n_title = "alerts_dashboard.contacted_peers_title",
   icon = "fas fa-exclamation",
}

-- ##############################################

function alert_contacted_peers:init(value, cli_or_srv, dyn_threshold, ip, host)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      value = value,
      cli_or_srv = cli_or_srv,
      dyn_threshold = dyn_threshold,
      ip = ip,
      host = host
   }
end

-- #######################################################

function alert_contacted_peers.format(ifid, alert, alert_type_params)
   local host = alert_type_params.host
   local numeric_ip = alert_type_params.ip
   local ip_label = host and host.label or numeric_ip

   if numeric_ip ~= host.host then
      numeric_ip = string.format("(%s)", numeric_ip)
   else
      numeric_ip = ""
   end

   local msg_params = {
      host = ip_label,
      numeric_ip = numeric_ip,
      dyn_threshold = alert_type_params.dyn_threshold,
      value = alert_type_params.value
   }

   if alert_type_params.cli_or_srv == true then
      return (i18n("alert_messages.alert_contacted_peers_as_cli", msg_params))
   else
      return (i18n("alert_messages.alert_contacted_peers_as_srv", msg_params))
   end
end

-- #######################################################

return alert_contacted_peers
