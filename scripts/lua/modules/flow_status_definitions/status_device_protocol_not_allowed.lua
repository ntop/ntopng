--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatSuspiciousDeviceProtocol(flowstatus_info)
   local msg, devtype

   if ((not flowstatus_info) or (flowstatus_info == "")) then
      return i18n("alerts_dashboard.suspicious_device_protocol")
   end

   local discover = require("discover_utils")
   local forbidden_proto = flowstatus_info["devproto_forbidden_id"] or 0

   if (flowstatus_info["devproto_forbidden_peer"] == "cli") then
      msg = "flow_details.suspicious_client_device_protocol"
      devtype = flowstatus_info["cli.devtype"]
   else
      msg = "flow_details.suspicious_server_device_protocol"
      devtype = flowstatus_info["srv.devtype"]
   end

   if(devtype == nil) then
      return i18n("alerts_dashboard.suspicious_device_protocol")
   end

   local label = discover.devtype2string(devtype)
   return i18n(msg, {proto=interface.getnDPIProtoName(forbidden_proto), devtype=label,
      url=getDeviceProtocolPoliciesUrl("device_type="..
      devtype.."&l7proto="..forbidden_proto)})
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_device_protocol_not_allowed,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_device_protocol_not_allowed,
  i18n_title = "flow_details.suspicious_device_protocol",
  i18n_description = formatSuspiciousDeviceProtocol
}
