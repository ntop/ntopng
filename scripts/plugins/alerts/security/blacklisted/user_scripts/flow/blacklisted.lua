--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")
local alert_severities = require "alert_severities"
local alerts_api = require "alerts_api"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.blacklisted",
      i18n_description = "flow_callbacks_config.blacklisted_description",
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   if flow.isBlacklisted() then
      local flow_info = flow.getInfo()
      local info = flow.getBlacklistedInfo()
      local flow_score = 100
      local cli_score, srv_score, attacker, victim

      if info["blacklisted.srv"] then
         cli_score = flow_consts.max_score
         srv_score = 5
         attacker = flow_info["srv.ip"]
         victim = flow_info["cli.ip"]
      else
         cli_score = 5
         srv_score = 10
         attacker = flow_info["cli.ip"]
         victim = flow_info["srv.ip"]
      end

      local blacklisted_type = flow_consts.status_types.status_blacklisted.create(
         info,
         attacker,
         victim
      )
     
      alerts_api.trigger_status(blacklisted_type, alert_severities.error, cli_score, srv_score, flow_score)
   end
end

-- #################################################################

return script
