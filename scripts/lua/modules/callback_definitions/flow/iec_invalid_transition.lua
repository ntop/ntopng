--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = true,
   alert_id = flow_alert_keys.flow_alert_iec_invalid_transition,

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
   },

   gui = {
      i18n_title        = "flow_callbacks.iec104_title",
      i18n_description  = "flow_callbacks.iec104_description",
   }
}

-- #################################################################

return script
