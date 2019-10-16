--
-- (C) 2019 - ntop.org
--

-- Companion scripts (in addition to i18n)
-- scripts/callbacks/status_defs/status_udp_unidirectional.lua
-- scripts/callbacks/interface/flow/udp.lua

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")

-- #################################################################

local script = {
   key = "udp_unidirectional",
   l4_proto = "udp",

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.udp_unidirectional",
      i18n_description = "flow_callbacks_config.udp_unidirectional_description",
      input_builder = user_scripts.flow_checkbox_input_builder,
   }
}

-- #################################################################

-- NOTE: what if at some point the flow receives a packet? We need to cancel the status bit
function script.hooks.all(params)
   local info = flow.getInfo()

   if(info["packets.rcvd"] == 0) then
      local info = flow.getUnicastInfo()

      -- Now check if the recipient isn't a broadcast/multicast address
      if(not(info["srv.broadmulticast"])) then
         -- TODO use flow.setStatus once #2950 is fixed
         flow.triggerStatus(flow_consts.status_types.status_udp_unidirectional.status_id)
      end
   -- else flow.clearStatus(flow_consts.status_types.status_udp_unidirectional.status_id)
   end
end

-- #################################################################

return script
