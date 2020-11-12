--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require ("user_scripts")
local alerts_api = require "alerts_api"

-- #################################################################

-- NOTE: this module is always enabled
local script = {
   -- Script category
   category = user_scripts.script_categories.network,

   packet_interface_only = true,
   nedge_exclude = true,
   l4_proto = "tcp",
   three_way_handshake_ok = true,

   -- Default values (will be made configurable from the UI)
   default_low_goodput_min_duration_secs = 600, -- 5 minutes
   default_low_goodput_threshold_pct     = 20,  -- Triggers the low goodput status if <=20%

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.tcp_issues_packets",
      i18n_description = "flow_callbacks_config.tcp_issues_packets_description",
   }
}

-- #################################################################

function script.hooks.periodicUpdate(now)
   if flow.getDuration() >= script.default_low_goodput_min_duration_secs then
      local cur_bytes = flow.getBytes()

      if cur_bytes > 0 then
	 local cur_goodput = flow.getGoodputBytes() / flow.getBytes() * 100

    if  cur_goodput <= script.default_low_goodput_threshold_pct then
      local low_goodput_type = flow_consts.status_types.status_low_goodput.create()

      alerts_api.trigger_status(low_goodput_type, flow_consts.status_types.status_low_goodput.alert_severity, 10, 10, 10)
	 end
      end
   end
end

-- #################################################################

return script
