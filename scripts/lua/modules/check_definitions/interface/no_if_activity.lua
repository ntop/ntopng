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

   severity = alert_consts.get_printable_severities().critical,

   gui = {
      i18n_title        = "checks.no_if_activity_title",
      i18n_description  = "checks.no_if_activity_description",
   }
}

-- #################################################################

local function check_interface_activity(params)
   -- Get total number of packets, flows and interface id
   local num_packets = params.entity_info.eth.packets
   local num_flows = params.entity_info.stats.new_flows -- .new_flows keep the cumulative total, .flows is just a gauge
   local num_logs = 0
   if params.entity_info.syslog then
      num_logs = params.entity_info.syslog.tot_events
   end

   local no_if_activity_type = alert_consts.alert_types.alert_no_if_activity.new(params.entity_info.name)

   no_if_activity_type:set_info(params)

   local delta_packets = alerts_api.interface_delta_val(params.check.key..".pkts" --[[ metric name --]], params.granularity, num_packets or 0)
   local delta_flows = alerts_api.interface_delta_val(params.check.key..".flows" --[[ metric name --]], params.granularity, num_flows or 0)
   local delta_logs = alerts_api.interface_delta_val(params.check.key..".logs" --[[ metric name --]], params.granularity, num_logs or 0)

   -- Check if the previous number it's equal to the actual number of both, packets and flows
   -- this distinction is done due to the fact that exist packet based interfaces
   -- and flow based interfaces
   if delta_packets == 0 and delta_flows == 0 and delta_logs == 0 then
      no_if_activity_type:trigger(params.alert_entity, nil, params.cur_alerts)
   else -- One of the two or both stats were different, so the interface is still active
      no_if_activity_type:release(params.alert_entity, nil, params.cur_alerts)
   end
end

-- #################################################################

script.hooks.min = check_interface_activity

-- #################################################################

return script
