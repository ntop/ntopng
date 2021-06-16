--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local checks = require("checks")
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
  -- Script category
  category = checks.script_categories.network,

  -- NB atm working only for packet interfaces
  packet_interface_only = true,

  -- This script is only for alerts generation
  alert_id = flow_alert_keys.flow_alert_zero_tcp_window,

  default_value = {
  },
  
  gui = {
    i18n_title        = "flow_callbacks.zero_tcp_window_title",
    i18n_description  = "flow_callbacks.zero_tcp_window_description",
  }
}

-- #################################################################

return script
