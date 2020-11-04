--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

-- #######################################################

local function noIfActivity(ifid, alert, no_if_activity_ctrs)
  return(i18n("no_if_activity.status_no_activity_description"))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_no_if_activity,
  i18n_title = "no_if_activity.alert_no_activity_title",
  i18n_description = noIfActivity,
  icon = "fas fa-arrow-circle-up",
  creator = alert_creators.createNoIfActivity,
}
