--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

local script = {
  -- Script category
  category = user_scripts.script_categories.security, 

  -- Priodity
  prio = 20, -- Higher priority (executed sooner) than default 0 priority

  -- This module is disabled by default
  default_enabled = false,

  -- This script is only for alerts generation
  is_alert = true,

  -- The default configuration of this script
  default_value = {
    severity = alert_severities.error,
    items = {},
  },

  -- Allow user script configuration from the GUI
  gui = {
    -- Localization strings, from the "locales" directory of the plugin
    i18n_title = "alerts_dashboard.blacklisted_country",
    i18n_description = "alerts_dashboard.blacklisted_country_descr",
    input_builder = "items_list",
    item_list_type = "country",
  }
}

-- #################################################################

return script
