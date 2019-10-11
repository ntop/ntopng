--
-- (C) 2019 - ntop.org
--
-- This scripts shows how to customize alert information
-- Rename it to user_scripts_prefs.lua to enable it.
--
local alert_consts = require("alert_consts")
local flow_consts = require("flow_consts")

-- Provide alternative alert visualization
alert_consts.overrideType(alert_consts.alert_types.custom_1, {
  i18n_title = "Example Alert",
  icon = "fa-life-ring",
})

-- Provide alternative flow status information and visualization
flow_consts.overrideStatus(flow_consts.custom_status_1, {
  relevance = 20,
  prio = 100,
  i18n_title = "This is an example status",
  alert_type = alert_consts.alert_types.custom_1,
  severity = alert_consts.alert_severities.error,
})
