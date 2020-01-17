--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")

-- #################################################################

local script = {
   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.blacklisted",
      i18n_description = "flow_callbacks_config.blacklisted_description",
      input_builder = 'elephant_flows'
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   if flow.isBlacklisted() then
      local info = flow.getBlacklistedInfo()
      local flow_score = 100
      local cli_score, srv_score

      if info["blacklisted.srv"] then
         cli_score = 100
         srv_score = 5
      else
         cli_score = 5
         srv_score = 10
      end

      flow.triggerStatus(flow_consts.status_types.status_blacklisted.status_id, info,
         flow_score, cli_score, srv_score)
   end
end

-- #################################################################

return script
