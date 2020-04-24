--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @return A table with the alert built
local function buildLoginFailedType(alert_severity)
  local built = {
     alert_severity = alert_severity,
     alert_type_params = {
     },
  }

  return built
end


-- #######################################################

local function loginFailedFormatter(ifid, alert, info)
  return(i18n("user_activity.login_not_authorized", {
    user = alert.alert_entity_val,
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_login_failed,
  i18n_title = "alerts_dashboard.login_failed",
  i18n_description = loginFailedFormatter,
  icon = "fas fa-sign-in",
  builder = buildLoginFailedType,
}
