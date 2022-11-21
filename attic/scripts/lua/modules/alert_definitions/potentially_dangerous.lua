--
-- (C) 2019-22 - ntop.org
--

local checks = require("checks")
local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.security,

   -- This script is only for alerts generation
   alert_id = flow_alert_keys.flow_alert_potentially_dangerous,

   default_value = {
   },

   gui = {
      i18n_title = "flow_checks_config.potentially_dangerous_protocol",
      i18n_description = "flow_checks_config.potentially_dangerous_protocol_description",
   }
}

-- #################################################################

function script.setup()
   -- IMPORTANT: this check is essential to prevent users from running enterprise
   -- scripts from pro
   if(not ntop.isEnterpriseM()) then
      return false
   end

   return true
end

-- #################################################################

return script
