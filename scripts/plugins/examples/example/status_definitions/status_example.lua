--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- This file defines a new flow status, with key "status_example" (the file name).
-- A flows status can set/unset by the user scripts located into the "user_scripts"
-- directory of the plugin.

-- #################################################################

-- @brief This function is called each time this status should be formatted
-- @param flowstatus_info: the data passed in flow.triggerStatus by
-- the triggering user_script (user_scripts/flow/example.lua in this plugin).
-- @return a descriptive string of the flow status
local function formatExampleStatus(flowstatus_info)
  local bad_port = flowstatus_info.bad_port

  return i18n("example.status_invalid_port", {port_number = bad_port})
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_example,
  -- alert_type: the alert type associated to this status
  -- alert_severity: the alert severity associated to this status
  -- i18n_title: a localization string for the status
  -- i18n_description (optional): a localization string / function for the description

  -- A label to associate to this status
  i18n_title = "example.status_title",

  -- A descriptive message of the status. Can be either a simple localized string
  -- e.g. "example.simple_status" or, as in this case, a formatter function.
  i18n_description = formatExampleStatus,

  -- The severity of the alert triggered based on this status
  alert_severity = alert_consts.alert_severities.error,

  -- The alert associated to this status. "alert_example" here corresponds
  -- to the alert key of example/alert_definitions/alert_example.lua
  alert_type = alert_consts.alert_types.alert_example,
}
