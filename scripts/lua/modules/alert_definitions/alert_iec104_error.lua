--
-- (C) 2019-20 - ntop.org
--

local alert_keys   = require "alert_keys"
local format_utils = require "format_utils"
local json         = require("dkjson")

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
local function createIEC104Error(alert_severity, alert_granularity, alert_subtype, last_error)
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

local function formatIEC104ErrorMessage(ifid, alert, status)
   local msg = json.decode(status.error_msg)
   local vlanId = alert.vlanId or 0
   local client = ip2label(msg.client.ip, msg.vlanId)
   local server = ip2label(msg.server.ip, msg.vlanId)

   local rsp = format_utils.formatEpoch(msg.timestamp)..": " ..
      "<A HREF=\""..hostinfo2detailsurl(client) .."\">".. msg.client.ip .."</A>"..
      " <i class=\"fas fa-exchange-alt fa-lg\" aria-hidden=\"true\" data-original-title=\"\" title=\"\"></i>" ..
      "<A HREF=\""..hostinfo2detailsurl(server) .."\">".. msg.server.ip .."</A>"..
      " [CauseTX: "..msg.cause_tx.."][TypeId: "..msg.type_id.."][ASDU: ".. msg.asdu.."][Negative: "

   if(msg.negatiive == false) then
      rsp = rsp .. "True]"
   else
      rsp = rsp .. "False]"
   end
   
   -- tprint(rsp)
   
   return(rsp)
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_iec104_error,
  i18n_title = "alerts_dashboard.iec104_error",
  i18n_description = formatIEC104ErrorMessage,
  icon = "fas fa-subway",
  creator = createIEC104Error,
}
