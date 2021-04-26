--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"


-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  -- NB atm working only for packet interfaces
  packet_interface_only = true,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_tcp_no_data_exchanged,

  default_value = {
   severity = alert_severities.warning,
  },
  
  gui = {
    i18n_title        = "tcp_no_data_exchanged.tcp_no_data_exchanged_title",
    i18n_description  = "tcp_no_data_exchanged.tcp_no_data_exchanged_description",
  }
}

-- #################################################################

return script
