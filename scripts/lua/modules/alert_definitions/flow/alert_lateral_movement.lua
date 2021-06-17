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

local alert_lateral_movement = classes.class(alert)

-- ##############################################

alert_lateral_movement.meta = {
   alert_key = flow_alert_keys.flow_alert_lateral_movement,
   i18n_title = "alerts_dashboard.lateral_movement",
   icon = "fas fa-fw fa-arrows-alt-h",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A table containing the last lateral movement error, e.g.,
--                   {"event":"create","shost":"192.168.2.153","dhost":"224.0.0.68","dport":1968,"vlan_id":0,"l4":17,"l7":0,"first_seen":1602488355,"last_seen":1602488355,"num_uses":1}
-- @return A table with the alert built
function alert_lateral_movement:init(last_error)
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_lateral_movement.format(ifid, alert, alert_type_params)
   local vlan_id = alert_type_params.vlan_id or 0
   local client = {host = alert_type_params.shost, vlan = vlan_id}
   local server = {host = alert_type_params.dhost, vlan = vlan_id}

   local rsp = hostinfo2detailshref(client, nil, hostinfo2label(client))..
      " <i class=\"fas fa-fw fa-exchange-alt fa-lg\" aria-hidden=\"true\" data-original-title=\"\" title=\"\"></i> " ..
      hostinfo2detailshref(server, nil, hostinfo2label(server))

   rsp = rsp .. " ["..alert_type_params.l7_proto.."]"
   if not isEmptyString(alert_type_params.info) then
      rsp = rsp .. "[" .. alert_type_params.info .. "]"
   end

   return(rsp)
end

-- #######################################################

return alert_lateral_movement
