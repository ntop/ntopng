--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"

-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "flow_callbacks_config.remote_to_remote",
    i18n_description = "flow_callbacks_config.remote_to_remote_description",
  }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   if(flow.isRemoteToRemote() and flow.isUnicast()) then
      local remote_to_remote_type = flow_consts.status_types.status_remote_to_remote.create(
        server_ip
      )

      alerts_api.trigger_status(remote_to_remote_type, alert_severities.notice, 10, 10, 10)
  end
end

-- #################################################################

return script
