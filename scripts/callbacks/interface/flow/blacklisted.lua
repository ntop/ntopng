--
-- (C) 2019 - ntop.org
--

local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local do_trace = false

-- #################################################################

local check_module = {
   key = "blacklisted",

   gui = {
      i18n_title = "flow_callbacks_config.blacklisted",
      i18n_description = "flow_callbacks_config.blacklisted_description",
      input_builder = alerts_api.flow_checkbox_input_builder,
   }
}


-- #################################################################

function check_module.setup()
   return false -- TODO: activate when migration to lua flow alerts completed
end

-- #################################################################

function check_module.protocolDetected(flow_info)
   if flow_info["cli.blacklisted"] or flow_info["srv.blacklisted"] then
      alerts_api.storeFlowAlert(alert_consts.alert_types.flow_blacklisted, alert_consts.alert_severities.error, flow_info)
   end
end

-- #################################################################

return check_module
