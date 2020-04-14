--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

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
}
