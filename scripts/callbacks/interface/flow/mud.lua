--
-- (C) 2019 - ntop.org
--

local mud_utils = require "mud_utils"
local alerts_api = require "alerts_api"

-- #################################################################

local check_module = {
   key = "mud",

   gui = {
      i18n_title = "flow_callbacks_config.mud",
      i18n_description = "flow_callbacks_config.mud_description",
      input_builder = alerts_api.flow_checkbox_input_builder,
   }
}


-- #################################################################

function check_module.setup()
  return(mud_utils.isMUDRecordingEnabled(interface.getId()))
end

-- #################################################################

function check_module.protocolDetected(info)
  mud_utils.handleFlow(info)
end

-- #################################################################

return check_module
