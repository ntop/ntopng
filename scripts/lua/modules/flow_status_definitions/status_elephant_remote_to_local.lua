--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatElephantStatus(flowstatus_info)
   return(formatElephantFlowStatus(flowstatus_info, false --[[ r2l ]]))
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_elephant_remote_to_local,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_flow_misbehaviour,
  i18n_title = "flow_details.elephant_flow_r2l",
  i18n_description = formatElephantStatus
}
