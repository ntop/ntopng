--
-- (C) 2019-20 - ntop.org
--

local mud_utils = require "mud_utils"
local user_scripts = require("user_scripts")
local discover = require("discover_utils")

local enabled_device_types
local max_recording

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   -- NOTE: hooks defined below
   hooks = {},
   default_enabled = false,

   default_value = {
    device_types = {'printer', 'video', 'iot'},
    max_recording = 3600,
  },

   gui = {
      i18n_title = "flow_callbacks_config.mud",
      i18n_description = "flow_callbacks_config.mud_description",
      input_builder = "flow_mud",
      item_list_type = "device_type",
   }
}

-- #################################################################

function script.setup()
  enabled_device_types = nil

  return(true)
end

-- #################################################################

function script.hooks.protocolDetected(now, conf)
  if(enabled_device_types == nil) then
    local device_types = conf.device_types or script.default_value.device_types
    max_recording = conf.max_recording or script.default_value.max_recording
  
    enabled_device_types = {}

    -- Convert the device type into an ID
    for _, devtype in pairs(device_types) do
      local id = discover.devtype2id(devtype)

      enabled_device_types[id] = true
    end
  end

  mud_utils.handleFlow(now, enabled_device_types, max_recording)
end

-- #################################################################

return script
