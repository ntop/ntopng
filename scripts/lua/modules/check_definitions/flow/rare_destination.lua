--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  packet_interface_only = true,
  
  -- Script category
  category = checks.check_categories.network,

  packet_interface_only = true,
  nedge_exclude = true,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_low_goodput,

  default_value = {
    
  },
  
  gui = {
    i18n_title = "flow_checks.rare_destination_title",
    i18n_description = "flow_checks.rare_destination_description",
  }
}

-- #################################################################

return script
