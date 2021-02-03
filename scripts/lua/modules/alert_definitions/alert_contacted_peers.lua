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
local json = require ("dkjson")

-- ##############################################

local alert_contacted_peers = classes.class(alert)

-- ##############################################

alert_contacted_peers.meta = {
   alert_key = alert_keys.ntopng.alert_contacted_peers,
   i18n_title = "alerts_dashboard.contacted_peers_title",
   icon = "fas fa-exclamation",
}

-- ##############################################

function alert_contacted_peers:init(value_srv, value_cli, dyn_threshold_srv, dyn_threshold_cli)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      value_cli = value_cli,
      value_srv = value_srv,
      dyn_threshold_cli = dyn_threshold_cli,
      dyn_threshold_srv = dyn_threshold_srv
   }
end

-- #######################################################

function alert_contacted_peers.format(ifid, alert, alert_type_params)
   local alert_consts = require "alert_consts"
   local host = firstToUpper(alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"]))
   local host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info)
   local triggered_as_srv = false
   local triggered_as_cli = false

   local msg_params = {
      host = host,
      host_category = host_category
   }

   if((type(alert_type_params.value_cli) == number) and (alert_type_params.value_cli > 0)) then
      msg_params.value_cli = alert_type_params.value_cli
      msg_params.dyn_threshold_cli = alert_type_params.dyn_threshold_cli
      triggered_as_cli = true
   end 

   if((type(alert_type_params.value_srv) == number) and (alert_type_params.value_srv > 0)) then
      msg_params.value_srv = alert_type_params.value_srv
      msg_params.dyn_threshold_srv = alert_type_params.dyn_threshold_srv
      triggered_as_srv = true
   end

   if triggered_as_srv == true and triggered_as_cli == true then
      return (i18n("alert_messages.contacted_peers", msg_params))
   elseif triggered_as_srv == true then
      return (i18n("alert_messages.contacted_peers_as_srv", msg_params))
   else
      return (i18n("alert_messages.contacted_peers_as_cli", msg_params))
   end   	 
end

-- #######################################################

return alert_contacted_peers
