--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   key = "my_custom_script",

   -- NOTE: hooks defined below
   hooks = {},
}

-- #################################################################

function script.setup()
   return(false)
   --return(true) -- enable
end

-- #################################################################

function script.hooks.protocolDetected(params)
   if(true --[[ some condition]]) then
      -- See scripts/lua/modules/user_scripts_prefs.sample.lua for details
      -- on how to customize the status/alert information
      flow.addStatus(flow_consts.custom_status_1)
   end
end

-- #################################################################

return script
