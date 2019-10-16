--
-- (C) 2019 - ntop.org
--

local alert_consts = require("alert_consts")

-- #################################################################

local function formatElephantStatus(status, flowstatus_info)
   return(formatElephantFlowStatus(status, flowstatus_info, false --[[ r2l ]]))
end

-- #################################################################

return {
  status_id = 18,
  relevance = 20,
  prio = 431,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_flow_misbehaviour,
  i18n_title = "flow_details.elephant_flow_r2l",
  i18n_description = formatElephantStatus
}
