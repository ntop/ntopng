--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require "alert_consts"
local checks = require("checks")

local script = {
   -- Script category
   category = checks.check_categories.internals,

   default_enabled = true,
   hooks = {},

   severity = alert_consts.get_printable_severities().emergency,

   gui = {
      i18n_title        = "checks.no_exporter_activity_title",
      i18n_description  = "checks.no_exporter_activity_description",
   }
}

-- #################################################################

local function check_exporter_activity(params)

   if not interface.isZMQInterface() then
      return -- Not a zmq interface, skip this check
   end

   --[[ Sample code for triggering alert:
   local exporter = params.entity_info.name .. '@' .. "1.2.3.4"
   params.entity_info.name = exporter 
   local no_exporter_activity_type = alert_consts.alert_types.alert_no_exporter_activity.new(params.entity_info.name)
   no_exporter_activity_type:set_info(params)
   no_exporter_activity_type:trigger(params.alert_entity, nil, params.cur_alerts)
   --]]

   -- Engaged alerts should be automatically released on next iteration
   --no_exporter_activity_type:release(params.alert_entity, nil, params.cur_alerts)
end

-- #################################################################

script.hooks.min = check_exporter_activity

-- #################################################################

return script
