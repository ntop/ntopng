--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.flow_risk",
      i18n_description = "flow_callbacks_config.flow_risk_description",
   }
}

-- #################################################################

function script.hooks.protocolDetected(now)
   local flow_risk = flow.getRiskInfo()

   -- For value information see nDPI/src/include/ndpi_typedefs.h
   for label,value in pairs(flow_risk) do
      if(value == 4) then
	 -- NDPI_BINARY_APPLICATION_TRANSFER
	 -- scripts/lua/modules/alert_definitions/alert_binary_application_transfer.lua
	 flow.triggerStatus(
	    flow_consts.status_types.status_binary_application_transfer.create(
	       flow_consts.status_types.status_binary_application_transfer.alert_severity,
	       info
	    ),
	    200, -- flow_score
	    200, -- cli_score
	    200  -- srv_score
	 )
      elseif(value == 5) then
	 -- NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT
	 -- scripts/lua/modules/alert_definitions/alert_known_proto_on_non_std_port.lua
	 flow.triggerStatus(
	    flow_consts.status_types.status_known_proto_on_non_std_port.create(
	       flow_consts.status_types.status_known_proto_on_non_std_port.alert_severity,
	       info
	    ),
	    100, -- flow_score
	    100, -- cli_score
	    100  -- srv_score
	 )
      end

      -- TODO: handle additional nDPI risks identified
      
      -- io.write("[flow_risks.lua] Risk "..value.."/"..label.." found\n")
   end
end

-- #################################################################

return script
