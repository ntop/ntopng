--
-- (C) 2019 - ntop.org
--

local mud_utils = require "mud_utils"
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   key = "mud",

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.mud",
      i18n_description = "flow_callbacks_config.mud_description",
      input_builder = user_scripts.flow_checkbox_input_builder,
   }
}

-- #################################################################

function script.setup()
  return(mud_utils.isMUDRecordingEnabled(interface.getId()))
end

-- #################################################################

function script.hooks.protocolDetected(params)
  mud_utils.handleFlow(params.flow_info)
end

-- #################################################################

return script
