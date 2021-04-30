--
-- (C) 2019-21 - ntop.org
--

local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"

-- #################################################################

local script

-- #################################################################

local function check_pool_connection_disconnection(params)
   local ifid = interface.getId()
   -- TODO: migrate code from alert utils to here
   alert_utils.check_host_pools_alerts(params, ifid, true --[[ alert_pool_connection_enabled --]], false --[[ alerts_on_quota_exceeded --]])
end

-- #################################################################

script = {
   -- Script category
   category = user_scripts.script_categories.network,

   default_enabled = false,

   -- This script is only for alerts generation
   is_alert = true,

   default_value = {
      severity = alert_severities.warning,
   },

   hooks = {
      min = check_pool_connection_disconnection,
   },

   gui = {
      i18n_title = "pool_connection_disconnection.title",
      i18n_description = "pool_connection_disconnection.description",
   },
}

-- #################################################################

return script
