--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

local function formatLongLivedFlow(status, flowstatus_info)
   local threshold = ""
   local res = i18n("flow_details.longlived_flow")

   if not flowstatus_info then
      return res
   end

   if flowstatus_info["longlived.threshold"] then
      threshold = flowstatus_info["longlived.threshold"]
   end

   res = string.format("%s<sup><i class='fa fa-info-circle' aria-hidden='true' title='"..i18n("flow_details.longlived_flow_descr").."'></i></sup>", res)

   if threshold ~= "" then
      res = string.format("%s [%s]", res, i18n("flow_details.longlived_exceeded", {amount = secondsToTime(threshold)}))
   end

   return res
end

-- #################################################################

return {
  status_id = 19,
  relevance = 20,
  prio = 440,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_flow_misbehaviour,
  i18n_title = "flow_details.longlived_flow",
  i18n_description = formatLongLivedFlow
}
