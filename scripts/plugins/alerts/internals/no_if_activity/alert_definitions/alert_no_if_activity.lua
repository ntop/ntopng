--
-- (C) 2020 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

-- #######################################################

local function noIfActivity(ifid, alert, no_if_activity_ctrs)
  return(i18n("no_if_activity.status_no_activity_description"))
end

-- ##############################################

local function createNoIfActivity(alert_severity, alert_granularity)
  local no_if_activity_type = {
     alert_granularity = alert_granularity,
     alert_severity = alert_severity,
     alert_type_params = {}
  }

  return no_if_activity_type
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_no_if_activity,
  i18n_title = "no_if_activity.alert_no_activity_title",
  i18n_description = noIfActivity,
  icon = "fas fa-arrow-circle-up",
  creator = createNoIfActivity,
}
