--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatIDSAlert(alert)
   local signature = (alert and alert.signature)
   local category = (alert and alert.category)
   local signature_info = (signature and signature:split(" "));
   local maker = (signature_info and table.remove(signature_info, 1))
   local scope = (signature_info and table.remove(signature_info, 1))
   local msg = (signature_info and table.concat(signature_info, " "))
   if maker and alert_consts.ids_rule_maker[maker] then
      maker = alert_consts.ids_rule_maker[maker]
   end
   return i18n("flow_details.ids_alert", { scope=scope, msg=msg, maker=maker })
end

-- #################################################################

local function formatExternalAlert(flowstatus_info)
   local res = i18n("alerts_dashboard.external_alert")

   if not flowstatus_info then
      return res
   end

   -- Available fields:
   -- flowstatus_info.source (e.g. suricata)
   -- flowstatus_info.severity_id (custom severity)
   -- flowstatus_info.alert (alert metadata)

   if flowstatus_info.source == "suricata" then
      res = formatIDSAlert(flowstatus_info.alert)
   end

   return res
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_external_alert,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.external_alert,
  i18n_title = "alerts_dashboard.external_alert",
  i18n_description = formatExternalAlert
}
