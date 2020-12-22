--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"

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
      local not_purged_type = flow_consts.status_types.status_not_purged.create()

      alerts_api.trigger_status(not_purged_type, alert_severities.error, 10, 10, 10)
   end
end

-- #################################################################

return script
