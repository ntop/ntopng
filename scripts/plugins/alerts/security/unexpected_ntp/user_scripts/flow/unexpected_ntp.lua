--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")
local alerts_api = require "alerts_api"
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
   l7_proto_id = 9, -- 9 == NTP

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
      items = {},
   },

   gui = {
      i18n_title        = "unexpected_ntp.unexpected_ntp_title",
      i18n_description  = "unexpected_ntp.unexpected_ntp_description",

      input_builder     = "items_list",
      item_list_type    = "string",
      input_title       = i18n("unexpected_ntp.title"),
      input_description = i18n("unexpected_ntp.description"),
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
   if(table.len(conf.items) > 0) then
      ok = 0
      server_ip =  flow.getServerKey()

      -- the string format returned by flow.geServerKey() is "x.x.x.x@0", :sub(1, -3) deletes "@0"
      server_ip = server_ip:sub(1, -3)

      for _, ntp_ip in pairs(conf.items) do
	 if server_ip == ntp_ip then
	    ok = 1
	 end
      end

      if ok == 0 then
         local unexpected_ntp_type = flow_consts.status_types.status_unexpected_ntp.create(
            server_ip
         )

         alerts_api.trigger_status(unexpected_ntp_type, alert_consts.alert_severities.error, 0, 100, 100)
      end
   end
end

-- #################################################################

return script
