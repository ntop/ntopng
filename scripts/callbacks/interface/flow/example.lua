--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "My Custom script",
      i18n_description = "Trigger an alert when something bad happens",
   }
}

-- #################################################################

function script.setup()
   return(false)
   --return(true) -- enable
end

-- #################################################################

function script.hooks.protocolDetected(now)
   if(true --[[ some condition]]) then
      -- NOTE: the status must be manually defined in scripts/callbacks/status_defs/custom_status_1.lua
      -- See scripts/callbacks/status_defs/custom_status_1.lua.example for details
      flow.triggerStatus(flow_consts.custom_status_1, "My custom status info")
   end
end

-- #################################################################

return script
