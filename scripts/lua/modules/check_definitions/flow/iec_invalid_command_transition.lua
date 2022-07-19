--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"
local IEC_INVALID_TRANSITION_KEY = "ntopng.checks.iec104_invalid_command_transition_enable"
-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   default_enabled = false,
   packet_interface_only = true,

   alert_id = flow_alert_keys.flow_alert_iec_invalid_command_transition,

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
   },

   gui = {
      i18n_title        = "flow_checks.iec104_command_title",
      i18n_description  = "flow_checks.iec104_command_description",
   }
}

-- #################################################################

function script.onEnable()
  ntop.setCache(IEC_INVALID_TRANSITION_KEY, "1")
end

-- #################################################################

function script.onDisable()
  ntop.setCache(IEC_INVALID_TRANSITION_KEY, "0")
end

return script
