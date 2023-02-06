--
-- (C) 2019-23 - ntop.org
--

local checks = require("checks")
local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"
local flow_alert_keys = require "flow_alert_keys"


-- #################################################################

-- NOTE: this module is always enabled
local script = {
   -- Script category
   category = checks.check_categories.security,

   -- This module is disabled by default
   default_enabled = false,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_vlan_bidirectional_traffic,

   default_value = {
      items = {},
   },
   
   gui = {
      i18n_title = "flow_checks_config.vlan_bidirectional_traffic",
      i18n_description = "flow_checks_config.vlan_bidirectional_traffic_description",
   
      input_builder     = "items_list",
      item_list_type    = "vlan",
      input_title       = "flow_checks.vlan_inclusion_list",
      input_description = "flow_checks.vlan_inclusion_list_description",
   
   }
}

return script