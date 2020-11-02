--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")

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
   l7_proto_id = 5, -- 5 == DNS

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
      items = {},
   },

   gui = {
      i18n_title        = "unexpected_dns.unexpected_dns_title",
      i18n_description  = "unexpected_dns.unexpected_dns_description",

      input_builder     = "items_list",
      item_list_type    = "string",
      input_title       = i18n("unexpected_dns.title"),
      input_description = i18n("unexpected_dns.description"),
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
      local ok = 0
      local flow_info = flow.getInfo()
      local server_ip = flow_info["srv.ip"]

      for _, dns_ip in pairs(conf.items) do
         if server_ip == dns_ip then
            ok = 1
            break
         end
      end

      if ok == 0 then
         flow.triggerStatus(
            flow_consts.status_types.status_unexpected_dns.create(
               flow_consts.status_types.status_unexpected_dns.alert_severity,
               server_ip
            ),
            100, -- flow_score
            0, -- cli_score
            100 --srv_score
         )
      end
   end
end

-- #################################################################

return script
