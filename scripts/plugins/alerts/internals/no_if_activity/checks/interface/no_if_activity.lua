--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require "alert_consts"
local checks = require("checks")

local script

-- #################################################################

local function check_interface_activity(params)
   -- Get total number of packets, flows and interface id
   local num_packets = params.entity_info.eth.packets
   local num_flows = params.entity_info.stats.new_flows -- .new_flows keep the cumulative total, .flows is just a gauge
   local num_logs = 0
   if params.entity_info.syslog then
      num_logs = params.entity_info.syslog.tot_events
   end

   local no_if_activity_type = alert_consts.alert_types.alert_no_if_activity.new()

   no_if_activity_type:set_score_error()
   no_if_activity_type:set_subtype(getInterfaceName(interface.getId()))
   no_if_activity_type:set_granularity(params.granularity)

   local delta_packets = alerts_api.interface_delta_val(params.check.key..".pkts" --[[ metric name --]], params.granularity, num_packets or 0)
   local delta_flows = alerts_api.interface_delta_val(params.check.key..".flows" --[[ metric name --]], params.granularity, num_flows or 0)
   local delta_logs = alerts_api.interface_delta_val(params.check.key..".logs" --[[ metric name --]], params.granularity, num_logs or 0)

   -- tprint(">>> selected: "..interface.getId() .. " name: "..getInterfaceName(interface.getId()))
   -- tprint(params.alert_entity)
   -- tprint("delta_packets: "..delta_packets.. " delta_flows: "..delta_flows.. " delta_logs: "..delta_logs)
   -- tprint("num_packets: "..num_packets.. " num_flows: "..num_flows.. " num_logs: "..num_logs)
   -- tprint("<<<")

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

script = {
   -- Script category
   category = checks.check_categories.internals,

   default_enabled = true,
   hooks = {
      -- Time past between one call and an other
      --["5mins"] = check_interface_activity,
      min = check_interface_activity,
   },


   gui = {
      i18n_title        = "no_if_activity.no_if_activity_title",
      i18n_description  = "no_if_activity.no_if_activity_description",
   }
}

-- #################################################################

return script
