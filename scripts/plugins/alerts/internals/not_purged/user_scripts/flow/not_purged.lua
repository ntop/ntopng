--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.internals,

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.not_purged",
      i18n_description = "flow_callbacks_config.not_purged_description",
   }
}

-- #################################################################

function script.hooks.periodicUpdate(now)
   if flow.isNotPurged() then
      local not_purged_type = alert_consts.alert_types.alert_internals.new()

      alert:set_severity(alert_severities.error)

      alert:trigger_status(10, 10, 10)
   end
end

-- #################################################################

return script
