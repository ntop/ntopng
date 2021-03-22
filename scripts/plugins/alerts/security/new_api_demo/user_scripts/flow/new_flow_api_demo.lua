--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   filter = {
      -- Overrides filter.default_fields in the flow entry of user_scripts.available_subdirs
      -- This will make default filters populated only with the source IP
      -- NOTE: Fields must be in the filter.available_fields of the flow entry of user_scripts.available_subdirs
      default_fields = { "srv_addr", "srv_port", "proto" },
   },

   gui = {
      i18n_title = "New API Demo",
      i18n_description = "Demonstrate the use of the new API for flow alerts",
   }
}

-- #################################################################

return script
