--
-- (C) 2019 - ntop.org
--

local mud_utils = require "mud_utils"
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   -- NOTE: hooks defined below
   hooks = {},
   default_enabled = false,

   gui = {
      i18n_title = "flow_callbacks_config.mud",
      i18n_description = "flow_callbacks_config.mud_description",
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
  mud_utils.handleFlow(now)
end

-- #################################################################

return script
