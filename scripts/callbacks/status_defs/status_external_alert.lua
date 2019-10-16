--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

local function formatIDS(status, flowstatus_info)
   if not flowstatus_info then
      return i18n("alerts_dashboard.ids_alert")
   end

   local signature = (flowstatus_info.external_alert and flowstatus_info.external_alert.signature)
   local category = (flowstatus_info.external_alert and flowstatus_info.external_alert.category)
   local alert_severity = (flowstatus_info.external_alert and flowstatus_info.external_alert.severity)
   local signature_info = (signature and signature:split(" "));
   local maker = (signature_info and table.remove(signature_info, 1))
   local scope = (signature_info and table.remove(signature_info, 1))
   local msg = (signature_info and table.concat(signature_info, " "))
   if maker and alert_consts.ids_rule_maker[maker] then
     maker = alert_consts.ids_rule_maker[maker]
   end
   local res = i18n("flow_details.ids_alert", { scope=scope, msg=msg, severity=severity, maker=maker } )
   return res
end

-- #################################################################

return {
  status_id = 21,
  relevance = 0,
  prio = 680,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.external_alert,
  i18n_title = "alerts_dashboard.external_alert",
  i18n_description = formatIDS
}
