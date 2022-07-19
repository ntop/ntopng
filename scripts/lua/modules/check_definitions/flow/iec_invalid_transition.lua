--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"
local CHECKS_IEC_INVALID_TRANSITION = "ntopng.checks.iec104_invalid_transition_enabled"

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

function script.onEnable()
  ntop.setCache(CHECKS_IEC_INVALID_TRANSITION, "1")
end

-- #################################################################

function script.onDisable()
  ntop.setCache(CHECKS_IEC_INVALID_TRANSITION, "0")
end

-- #################################################################

return script
