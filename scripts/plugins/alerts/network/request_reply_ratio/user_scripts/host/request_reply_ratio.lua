--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local user_scripts = require("user_scripts")

local script

-- #################################################################

local function request_reply_ratio(params)
   -- Implemented in C++
end

-- #################################################################

script = {
  -- Script category
  category = user_scripts.script_categories.network,

  local_only = true,
  nedge_exclude = true,
  default_enabled = true,

  -- This script is only for alerts generation
  is_alert = true,

  hooks = {
    ["min"] = request_reply_ratio
  },

  default_value = {
    -- "< 50%"
    operator = "lt",
    threshold = 50,
    severity = alert_severities.warning,
  },

  gui = {
    i18n_title = "entity_thresholds.request_reply_ratio_title",
    i18n_description = "entity_thresholds.request_reply_ratio_description",
    i18n_field_unit = user_scripts.field_units.percentage,
    input_builder = "threshold_cross",
    field_max = 100,
    field_min = 1,
    field_operator = "lt";
  }
}

-- #################################################################

return script
