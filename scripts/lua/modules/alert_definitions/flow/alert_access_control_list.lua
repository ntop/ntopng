--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local l4_protocol_list = require "l4_protocol_list"

-- ##############################################

local alert_access_control_list = classes.class(alert)

-- ##############################################

alert_access_control_list.meta = {
   alert_key = flow_alert_keys.flow_alert_access_control_list,
   icon = "fas fa-fw fa-exclamation",
   i18n_title = "alerts_dashboard.access_control_list",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_access_control_list:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_access_control_list.format(ifid, alert, alert_type_params)
   local href = ntop.getHttpPrefix() .. '/lua/pro/admin/access_control_list.lua'
   local l7_proto = tonumber(alert.l7_proto) or 0
   if l7_proto == 0 then
      l7_proto = tonumber(alert.l7_master_proto) or 0
   end
   local params = {
      l4_proto = l4_protocol_list.l4_proto_to_string(alert.proto),
      cli = alert.cli_ip,
      srv = alert.srv_ip,
      port = alert.srv_port,
      app = interface.getnDPIProtoName(l7_proto),
      href = href,
   }

   -- ICMP flows have no port
   if (tonumber(alert.srv_port) or 0) == 0 then
      return i18n("alerts_dashboard.access_control_list_no_port_descr", params)
   end

   return i18n("alerts_dashboard.access_control_list_descr", params)
end

-- #######################################################

return alert_access_control_list
