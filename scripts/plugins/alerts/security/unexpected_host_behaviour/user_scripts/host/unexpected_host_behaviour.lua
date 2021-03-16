--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local plugins_utils = require "plugins_utils"

-- #################################################################

local script = {
   default_enabled = true,
   
   -- Script category
   category = user_scripts.script_categories.security, 

   -- This script is only for alerts generation
   is_alert = true,

   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "alerts_dashboard.unexpected_host_behaviour_title",
      i18n_description = "alerts_dashboard.sites_behaviour_description",
   }
}

local handle_behaviour_list = {
   "contacted_hosts_behaviour",
   "score_behaviour",
   "active_flows_behaviour",
}

-- #################################################################

function script.hooks.min(params)
   local stats = host.getBehaviourInfo() or nil
   local host_ip = host.getIp() or ""
   
   if stats then
      for _,behaviour in ipairs(handle_behaviour_list) do
	 if stats[behaviour] ~= nil then 
	    handler = plugins_utils.loadModule("unexpected_host_behaviour", behaviour)
	 end
	 
	 if handler and handler.handle_behaviour then
	    -- Handler expect three params, namely flow-, client- and server-scores
	    handler.handle_behaviour(params, stats[behaviour], host_ip)
	 end
      end
   end
end

-- #################################################################

return script
