--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

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
    flow.setStatus(flow_consts.status_types.status_remote_to_remote,
      10--[[ flow score]], 10--[[ cli score ]], 10--[[ srv score ]])
  end
end

-- #################################################################

return script
