--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require "alert_consts"
local checks = require("checks")

local script = {
   -- Script category
   category = checks.check_categories.internals,
   zmq_interface_only = true,
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
   local time_limit = os.time() - 60 -- Alert after 1 minute
   local debug = false
   
   if not interface.isZMQInterface() then
      return -- Not a zmq interface, skip this check
   end

   local ifstats = interface.getStats()

   for interface_id, probes_list in pairs(ifstats.probes or {}) do
      for source_id, probe_info in pairs(probes_list or {}) do
	 if not(probe_info["probe.last_update"] < time_limit) then
	    if(debug) then tprint("[NOK] Probe ["..probe_info["probe.ip"].."]: "..probe_info["probe.last_update"]) end
	    
	    if(probe_info["probe.last_update"] < time_limit) then
	       params.entity_info.name = params.entity_info.name .. '@' .. probe_info["probe.ip"]
	       local no_probe_activity_type = alert_consts.alert_types.alert_no_probe_activity.new(params.entity_info.name, probe_info["probe.last_update"])
	       no_probe_activity_type:set_info(params)
	       no_probe_activity_type:trigger(params.alert_entity, nil, params.cur_alerts)
	    end	    
	 else
	    -- Probe is ok, let's now check the exporters
	    if(debug) then tprint("[OK] Probe ["..probe_info["probe.ip"].."]: "..probe_info["probe.last_update"]) end
	    
	    for ip_addr, exp in pairs(probe_info.exporters) do
	       if(exp.time_last_used < time_limit) then
		  if(debug) then tprint("[NOK] Exporter "..ip_addr.."[probe "..probe_info["probe.ip"].."]: "..exp.time_last_used) end
		  
		  params.entity_info.name = params.entity_info.name .. '@' .. ip_addr
		  
		  local no_exporter_activity_type = alert_consts.alert_types.alert_no_exporter_activity.new(params.entity_info.name, exp.time_last_used)
		  no_exporter_activity_type:set_info(params)
		  no_exporter_activity_type:trigger(params.alert_entity, nil, params.cur_alerts)
	       else
		  if(debug) then tprint("[OK] Exporter "..ip_addr.." [probe "..probe_info["probe.ip"].."]: "..exp.time_last_used) end
	       end
	    end
	 end
      end
   end

   -- Engaged alerts should be automatically released on next iteration
   --no_exporter_activity_type:release(params.alert_entity, nil, params.cur_alerts)
end

-- #################################################################

script.hooks.min = check_exporter_activity

-- #################################################################

return script
