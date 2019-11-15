--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   -- NOTE: hooks defined below
   hooks = {},
   periodic_update_seconds = 600,

   gui = {
      i18n_title = "flow_callbacks_config.not_purged",
      i18n_description = "flow_callbacks_config.not_purged_description",
      input_builder = user_scripts.flow_checkbox_input_builder,
  }
}

-- #################################################################

function script.hooks.periodicUpdate(now)
   if flow.isNotPurged() then
      flow.triggerStatus(flow_consts.status_types.status_not_purged.status_id)
   end
end

-- #################################################################

return script
