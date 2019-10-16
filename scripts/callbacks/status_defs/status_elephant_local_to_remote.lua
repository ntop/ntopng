--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

local function formatElephantStatus(status, flowstatus_info)
   return(formatElephantFlowStatus(status, flowstatus_info, true --[[ l2r ]]))
end

-- #################################################################

return {
  status_id = 17,
  relevance = 20,
  prio = 430,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_flow_misbehaviour,
  i18n_title = "flow_details.elephant_flow_l2r",
  i18n_description = formatElephantStatus
}
