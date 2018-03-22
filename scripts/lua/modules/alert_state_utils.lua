--
-- (C) 2014-18 - ntop.org
--

--[[

This file contains a set of functions used to handle alerts that have a state. This kind of alerts
have, by definition, a duration associated and, thus, they can either be 'ongoing' or 'withdrawn'.

Alerts become 'ongoing' the first time they are fired, and must be explicitly 'withdrawn'
when they become unactive. 

--]]


j = require("dkjson") -- NOTE: this is already required in scripts/lua/modules/alert_utils.lua
require "persistence"

function get_host_ongoing_hash_name(ifid, host_ip, host_vlan)
   --[[
   generated hash name examples are:
   1) "ntopng.alerts.ifid_6.ongoing.hosts.192.168.2.126@0"
   2) "ntopng.alerts.ifid_6.ongoing.hosts.192.168.2.130@0"
   --]]

   if tonumber(ifid) == nil then return nil end
   if not isIPv4(host_ip) and not isIPv6(host_ip) then return nil end
   if tonumber(host_vlan) == nil or tonumber(host_vlan) < 0 then return nil end
   
   local host_ongoing_hash_name = "ntopng.alerts.%ifid%.ongoing.hosts.%host%"
   host_ongoing_hash_name = string.gsub(host_ongoing_hash_name,
					"%%ifid%%",
					"ifid_"..tostring(ifid))
   host_ongoing_hash_name = string.gsub(host_ongoing_hash_name,
					"%%host%%",
					tostring(host_ip).."@"..tostring(host_vlan))
   return host_ongoing_hash_name
end

function get_alert_ongoing_hash_key(alert_id, alert_type)
   if alert_type == nil or alert_type == "" or tostring(alert) == nil then return nil end

   -- the alert is identified by a mandatory type
   local key = "type_"..tostring(alert_type)
   -- and an optional id that uniquely represent an alert within its type
   if tostring(alert_id) ~= nil and tostring(alert_id) ~= "" then
      -- possibly app
      key = key.."_id_"..tostring(alert_id)
   end

   return key
end

function get_threshold_alert_id(timespan, metric)
   if is_allowed_timespan(timespan) == false or is_allowed_alarmable_metric(metric)  == false then
      return nil
   end

   -- the alert is identified by a mandatory type
   local alert_type = 2 -- for the type see alert_type_keys in lua_utils.lua
   local key = "type_"..tostring(alert_type)
   -- and an optional id that uniquely represent an alert within its type
   if tostring(alert_id) ~= nil and tostring(alert_id) ~= "" then
      -- possibly app
      key = key.."_id_"..tostring(timespan).."_"..tostring(metric)
   end

   return key
end

function forge_alert(alert, alert_severity, alert_type, alert_msg, close)
   if alert == nil or alert == "" then return nil end
   if alert_msg == nil then alert_msg = "" end

   local alert_j  = alert
   if type(alert) == "string" then
      alert_j = j.decode(alert, 1, nil)
   elseif type(alert) ~= "table" then
      return nil
   end

   -- do not override the first seen
   if alert_j["first_seen"] == nil then
      alert_j["first_seen"] = os.time()
   end

   -- set last_seen only if this call is to close an outgoing alert
   if close ~= nil and tonumber(close) ~= nil then
      alert_j["last_seen"] = close
   end

   -- always override those guys
   if alert_severity ~= nil and alert_severity ~= "" then
      alert_j["alert_severity"] = alert_severity
   end
   if alert_type ~= nil and alert_type ~= "" then
      alert_j["alert_type"] = alert_type
   end

   if alert_msg ~= nil and alert_msg ~= "" then
      alert_j["alert_msg"] = alert_msg
   end

   return alert_j
end

