--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   is_alert = true,

   -- Specify the default value when clicking on the "Reset Default" button
   default_value = {
      severity = alert_severities.warning,
      items = {
	 9,13,36,45,46,48,30,103,100,37
      },
   },

   gui = {
      i18n_title        = "iec_unexpected_type_id.iec104_title",
      i18n_description  = "iec_unexpected_type_id.iec104_description",
      input_builder     = "items_list", -- TODO: fix the input list
      input_title       = i18n("iec_unexpected_type_id.title"),
      input_description = i18n("iec_unexpected_type_id.description"),
   }
}

-- #################################################################

return script
