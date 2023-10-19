--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local flow_alert_keys = require "flow_alert_keys"
local CHECKS_IEC_UNEXPECTED_TYPE_ID = "ntopng.checks.iec104_unexpected_type_id_enabled"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   default_enabled = false,
   packet_interface_only = true,

   alert_id = flow_alert_keys.flow_alert_iec_unexpected_type_id,

   -- Specify the default value when clicking on the "Reset Default" button
   default_value = {
      items = {
	 9,13,36,45,46,48,30,103,100,37
      },
   },

   gui = {
      i18n_title        = "flow_checks.iec104_unexpected_type_id_title",
      i18n_description  = "flow_checks.iec104_unexpected_type_id_description",
      input_builder     = "items_list", -- TODO: fix the input list
      input_title       = "flow_checks.iec104_unexpected_type_id_allowed_type_ids_title",
      input_description = "flow_checks.iec104_unexpected_type_id_allowed_type_ids_description",
   }
}

-- #################################################################

function script.onEnable()
  ntop.setCache(CHECKS_IEC_UNEXPECTED_TYPE_ID, "1")
end

-- #################################################################

function script.onDisable()
  ntop.setCache(CHECKS_IEC_UNEXPECTED_TYPE_ID, "0")
end

return script
