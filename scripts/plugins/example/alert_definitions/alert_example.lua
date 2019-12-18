--
-- (C) 2019 - ntop.org
--

-- This file defines a new alert, with key "alert_example" (the file name)
-- Alerts can be triggered by the user scripts located into the "user_scripts"
-- directory of the plugin.

return {
  -- The unique alert ID. Currently used/available IDs can be reviewed by visiting
  -- http://127.0.0.1:3000/lua/defs_overview.lua .
  -- Third party users can safely use the dedicated IDs in range 59-63 .
  alert_id = 59,

  -- The name associated to this alert. Localized strings are defined in
  -- example/locales/en.lua
  i18n_title = "example.alert_title",

  -- An icon (css class name) associated to this alert. ntopng supports icons
  -- from https://fontawesome.com .
  icon = "fa-exclamation",

  -- An optional alert message to show when the alert is triggered. For flow
  -- alerts, however, the alert message is defined into the status associated
  -- to the alert, which is example/status_definitions/status_example.lua for
  -- this plugin.
  i18n_description = "example.alert_description",
}
