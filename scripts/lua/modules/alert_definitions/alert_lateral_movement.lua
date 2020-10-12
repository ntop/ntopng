--
-- (C) 2019-20 - ntop.org
--

local alert_keys   = require "alert_keys"
local format_utils = require "format_utils"
local json         = require("dkjson")

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
local function createLateralMovementError(alert_severity, alert_granularity, last_error)
   local threshold_type = {
      alert_severity = alert_severity,
      alert_subtype = alert_subtype,
      alert_granularity = alert_granularity,
      alert_type_params = {
	 error_msg = last_error
      },
   }

   return threshold_type
end

-- #######################################################

local function formatLateralMovementErrorMessage(ifid, alert, status)
   local msg = json.decode(status.error_msg)
   local vlan_id = alert.vlan_id or 0
   local client = ip2label(msg.shost, vlan_id)
   local server = ip2label(msg.dhost, vlan_id)

   local rsp = format_utils.formatEpoch(msg.timestamp)..": " ..
      "<A HREF=\""..hostinfo2detailsurl(client) .."\">".. msg.shost .."</A>"..
      " <i class=\"fas fa-exchange-alt fa-lg\" aria-hidden=\"true\" data-original-title=\"\" title=\"\"></i>" ..
      "<A HREF=\""..hostinfo2detailsurl(server) .."\">".. msg.dhost .."</A>"..
      " [Port: "..msg.dport.."]"

   if(vlan_id ~= 0) then
      rsp = rsp .. "[VLAN Id: " .. msg.info .. "]"
   end
   
   rsp = rsp .. "[L7: "..msg.l7.."]"
   if(msg.info ~= "") then
      rsp = rsp .. "[" .. msg.info .. "]"
   end
   
   -- tprint(rsp)
   
   return(rsp)
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_lateral_movement,
  i18n_title = "alerts_dashboard.lateral_movement",
  i18n_description = formatLateralMovementErrorMessage,
  icon = "fas fa-subway",
  creator = createLateralMovementError,
}
