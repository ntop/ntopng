--
-- (C) 2019-20 - ntop.org
--

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
local ts_utils = require("ts_utils_core")
local storage_utils = require("storage_utils")
local alerts_api = require("alerts_api")

local script = {
  -- Script category
  category = user_scripts.script_categories.system,

  -- This module is enabled by default
  default_enabled = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},

  gui = {
    i18n_title = "system_stats.disk_monitor",
    i18n_description = "system_stats.disk_monitor_description",
  },
}

-- ##############################################

-- Defines an hook which is executed every hour
function script.hooks.hour(params)
   local info = storage_utils.storageInfo(true --[[ refresh cache ]], 120 --[[ Allow a couple of minutes --]])

   -- TODO alert if free disk space is too low
end

-- ##############################################

return(script)
