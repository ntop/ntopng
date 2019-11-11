--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.blacklisted",
      i18n_description = "flow_callbacks_config.blacklisted_description",
      input_builder = user_scripts.flow_checkbox_input_builder,
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   if flow.isBlacklisted() then
      flow.triggerStatus(flow_consts.status_types.status_blacklisted.status_id, flow.getBlacklistedInfo())
   end
end

-- #################################################################

return script
