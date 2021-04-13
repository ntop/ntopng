--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require ("user_scripts")
local alert_severities = require "alert_severities"

-- #################################################################

local host_score = {
   -- Script category
   category = user_scripts.script_categories.security,

   default_enabled = false,

   default_value = {
      -- "> 1000"
      operator = "gt",
      threshold = 4096,
      severity = alert_severities.error,
   },

   gui = {
      i18n_title = "score",
      i18n_description = "alerts_dashboard.host_score_description",
      input_builder = "threshold_cross",
      field_max = 65535,
      field_min = 0,
      field_operator = "gt",
   }
}

-- #################################################################

return host_score
