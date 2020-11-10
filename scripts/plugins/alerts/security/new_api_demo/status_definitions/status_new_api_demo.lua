--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"
local alert_consts = require "alert_consts"

-- #################################################################

local function formatDemo(flowstatus_info)
   if flowstatus_info and flowstatus_info.one_param and flowstatus_info.another_param then
      return string.format("New API demo: [%s][%s]", flowstatus_info.one_param, flowstatus_info.another_param)
   end

   return "New API Demo"
end

-- #################################################################

return {
   status_key = status_keys.user.status_user_03,
   alert_type = alert_consts.alert_types.alert_new_api_demo,
   i18n_title = "New API Demo",
   i18n_description = formatDemo
}
