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
   key = "udp",

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
function script.hooks.protocolDetected(params)
   local packets = flow.getPackets()

   if(packets["packets.rcvd"] == 0) then
      local server = flow.getServerIp()

      -- Now check if the recipient isn't a broadcast/multicast address
      if(not(server["srv.broadmulticast"])) then
	 flow.triggerStatus(flow_consts.flow_status_types.status_udp_unidirectional.status_id)
      end
   end
end

-- #################################################################

return script
