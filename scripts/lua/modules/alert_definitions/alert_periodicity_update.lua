--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

require("lua_utils")

-- ##############################################

local alert_periodicity_update = classes.class(alert)

-- ##############################################

alert_periodicity_update.meta = {
   alert_key = alert_keys.ntopng.alert_periodicity_update,
   i18n_title = "alerts_dashboard.alert_periodicity_update",
   icon = "fas fa-arrows-alt-h",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A table containing the last lateral movement error, e.g.,
--                   {"event":"create","shost":"192.168.2.153","dhost":"224.0.0.68","dport":1968,"vlan_id":0,"l4":17,"l7":0,"first_seen":1602488355,"last_seen":1602488355,"num_uses":1}
-- @return A table with the alert built
function alert_periodicity_update:init(last_error, created_or_removed)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      error_msg = last_error,
      created_or_removed = created_or_removed
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_periodicity_update.format(ifid, alert, alert_type_params)
   local msg = alert_type_params.error_msg
   local vlan_id = msg.vlan_id or 0
   local client = {host = msg.shost, vlan = vlan_id}
   local server = {host = msg.dhost, vlan = vlan_id}
   local rsp

   if alert_type_params.created_or_removed == "create" then
      rsp = {
      	  host_info1 = hostinfo2detailshref(client, nil, hostinfo2label(client)),
	  host_info2 = hostinfo2detailshref(server, nil, hostinfo2label(server)),
	  l7_proto   = interface.getnDPIProtoName(msg.l7),
	  info 	     = shortenString(msg.info, 24) or "",
	  frequency  = msg.frequency or "",	  
      }

      return (i18n("alert_messages.periodicity_update_new", rsp))
   else
      rsp = {
      	  host_info1 = hostinfo2detailshref(client, nil, hostinfo2label(client)),
	  host_info2 = hostinfo2detailshref(server, nil, hostinfo2label(server)),
	  l7_proto   = interface.getnDPIProtoName(msg.l7),
	  info 	     = shortenString(msg.info, 24) or "",	  
      }
      
      return (i18n("alert_messages.periodicity_update_ended", rsp))
   end
end

-- #######################################################

return alert_periodicity_update
