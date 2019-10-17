--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")

-- #################################################################

local script = {
   key = "not_purged",

   -- NOTE: hooks defined below
   hooks = {},
}

-- #################################################################

function script.hooks.periodicUpdate(params)
   if flow.isNotPurged() then
      flow.triggerStatus(flow_consts.status_types.status_not_purged.status_id)
   end
end

-- #################################################################

return script
