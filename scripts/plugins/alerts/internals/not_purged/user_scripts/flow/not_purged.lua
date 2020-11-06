--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

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
      flow.triggerStatus(
	 flow_consts.status_types.status_not_purged.create(
	    flow_consts.status_types.status_not_purged.alert_severity
	 )
      )
   end
end

-- #################################################################

return script
