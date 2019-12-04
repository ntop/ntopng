--
-- (C) 2019 - ntop.org
--

local function loginFailedFormatter(ifid, alert, info)
  return(i18n("user_activity.login_not_authorized", {
    user = alert.alert_entity_val,
  }))
end

-- #######################################################

return {
  alert_id = 42,
  i18n_title = "alerts_dashboard.login_failed",
  i18n_description = loginFailedFormatter,
  icon = "fa-sign-in",
}
