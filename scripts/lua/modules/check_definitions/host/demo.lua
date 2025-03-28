--
-- (C) 2019-24 - ntop.org
--

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")
local host_alert_keys = require "host_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   -- This module is disabled by default
   default_enabled = false,

   -- This script is only for alerts generation
   alert_id = host_alert_keys.host_alert_demo,

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
      items = {},
   },

   gui = {
      i18n_title        = "entity_thresholds.demo_title",
      i18n_description  = "entity_thresholds.demo_description",
   }
}


-- #################################################################

return script
