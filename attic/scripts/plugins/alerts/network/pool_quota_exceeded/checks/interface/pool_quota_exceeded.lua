--
-- (C) 2019-21 - ntop.org
--

local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local checks = require("checks")

-- #################################################################

local script

-- #################################################################

local function check_pool_quota_exceeded(params)
   local ifid = interface.getId()
   -- TODO: migrate code from alert utils to here
   alert_utils.check_host_pools_alerts(params, ifid, false --[[ alert_pool_connection_enabled --]], true --[[ alerts_on_quota_exceeded --]])
end

-- #################################################################

script = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,


   default_value = {
   },

   -- This is only for nEdge
   nedge_only = true,

   hooks = {
      min = check_pool_quota_exceeded,
   },

   gui = {
      i18n_title = "pool_quota_exceeded.title",
      i18n_description = "pool_quota_exceeded.description",
   },
}

-- #################################################################

return script
