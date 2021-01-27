--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")

local UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY = "ntopng.cache.user_scripts.unexpected_plugins_enabled"

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security,

   -- Priority
   prio = -20, -- Lower priority (executed after) than default 0 priority

   -- This module is disabled by default
   default_enabled = false,

   -- NOTE: hooks defined below
   hooks = {},

   -- use this plugin only with this protocol
   l7_proto_id = 18, -- 18 == DHCP

   -- This script is only for alerts generation
   is_alert = true,

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
      severity = alert_severities.error,
      items = {},
   },

   gui = {
      i18n_title        = "unexpected_dhcp.unexpected_dhcp_title",
      i18n_description  = "unexpected_dhcp.unexpected_dhcp_description",

      input_builder     = "items_list",
      item_list_type    = "ip_address",
      input_title       = i18n("unexpected_dhcp.title"),
      input_description = i18n("unexpected_dhcp.description"),
   }
}

-- #################################################################

function script.onEnable(hook, hook_config)
   -- Set a flag to indicate to the notifications system that an unexpected plugin
   -- has been enabled
   if isEmptyString(ntop.getCache(UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY)) then
      ntop.setCache(UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY, "1")
   end
end

-- #################################################################

function script.hooks.protocolDetected(now, conf)
   if flow.isServerUnicast() then
      if(table.len(conf.items) > 0) then
         local ok = 0
         local flow_info = flow.getInfo()
	 local client_ip, server_ip
	 
	 if(flow_info["cli.protocol_server"]) then
	    client_ip = flow_info["srv.ip"]
	    server_ip = flow_info["cli.ip"]
	 else
	    client_ip = flow_info["cli.ip"]
	    server_ip = flow_info["srv.ip"]
	 end

         for _, dns_ip in pairs(conf.items) do
            if server_ip == dns_ip then
               ok = 1
               break
            end
         end

         if ok == 0 then
            local alert = alert_consts.alert_types.alert_unexpected_dhcp.new(
               client_ip, 
               server_ip
            )

            alert:set_severity(conf.severity)
            alert:set_attacker(server_ip)
            alert:set_victim(client_ip)

            alert:trigger_status(0, 100, 100)
         end
      end
   end
end

-- #################################################################

return script
