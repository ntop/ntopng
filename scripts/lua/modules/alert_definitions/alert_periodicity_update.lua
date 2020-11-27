--
-- (C) 2020 - ntop.org
--

local alert_keys   = require "alert_keys"
local format_utils = require "format_utils"
local json         = require("dkjson")

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param last_error A table containing the last lateral movement error, e.g.,
--                   {"event":"create","shost":"192.168.2.153","dhost":"224.0.0.68","dport":1968,"vlan_id":0,"l4":17,"l7":0,"first_seen":1602488355,"last_seen":1602488355,"num_uses":1}
-- @return A table with the alert built
local function createPeriodicityUpdateError(alert_severity, alert_granularity, last_error, created_or_removed)
   -- Create a subtype, to avoid merging multiple lateral movement alerts together
   local alert_subtype = last_error.shost .. "/" .. last_error.dhost .. "/" .. last_error.dport .. "/" .. last_error.l4 .. "/" .. last_error.l7
   local threshold_type = {
      alert_severity = alert_severity,
      alert_subtype = alert_subtype,
      alert_granularity = alert_granularity,
      alert_type_params = {
    error_msg = last_error,
    created_or_removed = created_or_removed
      },
   }

   return threshold_type
end

-- #######################################################

local function formatPeriodicityUpdateErrorMessage(ifid, alert, status)
   local msg = status.error_msg
   local vlan_id = msg.vlan_id or 0
   local client = {host = msg.shost, vlan = vlan_id}
   local server = {host = msg.dhost, vlan = vlan_id}
   local rsp

   if status.created_or_removed == "create" then
      rsp = "flow: "
      rsp = rsp .. hostinfo2detailshref(client, nil, hostinfo2label(client))..
      " <i class=\"fas fa-exchange-alt fa-lg\" aria-hidden=\"true\" data-original-title=\"\" title=\"\"></i> " ..
      hostinfo2detailshref(server, nil, hostinfo2label(server))..
      " ["..i18n("port")..": "..msg.dport.."]"
   
      rsp = rsp .. "["..i18n("application")..": "..interface.getnDPIProtoName(msg.l7).."]"
      if not isEmptyString(msg.info) then
         rsp = rsp .. "[" .. msg.info .. "]"
      end
      rsp = rsp .. ", is now periodic (frequency " .. msg["frequency"] .. " seconds)"
   else
      rsp = "Periodic flow ended: "
      rsp = rsp .. hostinfo2detailshref(client, nil, hostinfo2label(client))..
      " <i class=\"fas fa-exchange-alt fa-lg\" aria-hidden=\"true\" data-original-title=\"\" title=\"\"></i> " ..
      hostinfo2detailshref(server, nil, hostinfo2label(server))..
      " ["..i18n("port")..": "..msg.dport.."]"
   
      rsp = rsp .. "["..i18n("application")..": "..interface.getnDPIProtoName(msg.l7).."]"
      if not isEmptyString(msg.info) then
         rsp = rsp .. "[" .. msg.info .. "]"
      end
   end

   
   
   return(rsp)
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_periodicity_update,
  i18n_title = "alerts_dashboard.alert_periodicity_update",
  i18n_description = formatPeriodicityUpdateErrorMessage,
  icon = "fas fa-arrows-alt-h",
  creator = createPeriodicityUpdateError,
}