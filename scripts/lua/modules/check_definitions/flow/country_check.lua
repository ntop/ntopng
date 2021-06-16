--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

local script = {
  -- Script category
  category = checks.check_categories.security, 

  -- This module is disabled by default
  default_enabled = false,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_blacklisted_country,

  -- The default configuration of this script
  default_value = {
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
