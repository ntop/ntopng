--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.security,

  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    operator = "gt",
    threshold = 5,
    severity = alert_severities.error,
  },

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.dns_contacts_title",
    i18n_description = "alerts_thresholds_config.dns_contacts_description",
    i18n_field_unit = user_scripts.field_units.contacts,

    input_builder = "threshold_cross",
    field_max = 500,
    field_min = 1,
    field_operator = "gt";
  }
}

-- #################################################################

function script.hooks.min(params)
  local value = host.getContactsStats() or nil

  if not value then
    return
  end

  if value.server_contacts then
    value = value.server_contacts.dns or 0
  else
    value = 0
  end

  -- Check if the configured threshold is crossed by the value and possibly trigger an alert
  alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_threshold_cross, value)
end

-- #################################################################

return script