--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    items = {},
    default_contacts = 5,
    severity = alert_severities.error,
  },

  -- See below
  hooks = {},

  gui = {
    i18n_title = "alerts_thresholds_config.smtp_contacts_title",
    i18n_description = "alerts_thresholds_config.smtp_contacts_description",

    input_builder     = "items_list",
    item_list_type    = "ip_address",
    input_title       = i18n("input_item_list.smtp_input_list_title"),
    input_description = i18n("input_item_list.smtp_input_list_description"),
  }
}

-- #################################################################

function script.hooks.min(params)
  local value = host.getContactsStats() or nil
  local host_ip = params.entity_info.ip or ""
  local ok = 0

  if not value then
    return
  end

  for _, smtp_ip in pairs(params.user_script_config) do
    if host_ip == smtp_ip then
       ok = 1
       break
    end
  end


  if ok == 0 then
     if value.server_contacts then
     	value = value.server_contacts.smtp or 0
     else
	value = 0
     end

     local value = alerts_api.host_delta_val(script.key, params.granularity, value)

     -- Check if the configured threshold is crossed by the value and possibly trigger an alert
     
     alerts_api.checkThresholdAlert(params, alert_consts.alert_types.alert_threshold_cross, value)
  end
end

-- #################################################################

return script
