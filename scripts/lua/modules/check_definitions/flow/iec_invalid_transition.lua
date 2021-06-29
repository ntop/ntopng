--
-- (C) 2019-21 - ntop.org
--

local checks = require("checks")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   default_enabled = false,
   packet_interface_only = true,

   alert_id = flow_alert_keys.flow_alert_iec_invalid_transition,

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
   },

   gui = {
      i18n_title        = "flow_checks.iec104_title",
      i18n_description  = "flow_checks.iec104_description",
   }
}

-- #################################################################

return script
