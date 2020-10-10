--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   -- Priority
   prio = -20, -- Lower priority (executed after) than default 0 priority

   -- NOTE: hooks defined below
   hooks = {},

   -- use this plugin only with this protocol
   l7_proto_id = 5, -- 5 == DNS

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
      items = {},
   },

  
   -- The frequency for the periodicUpdate hook invocation. Must be
   -- multiple of 30 seconds.
   periodic_update_seconds = 30,

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

function script.hooks.protocolDetected(now, conf)
   ok = 0
   server_ip =  flow.getServerKey()

   -- the fortmat of the string returned by flow.geServerKey() is "x.x.x.x@0", :sub(1, -3) deletes "@0"
   server_ip = server_ip:sub(1, -3)

   for _, dns_ip in pairs(conf.items or script.default_value.items) do
       if server_ip == dns_ip then
           ok = 1
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

-- #################################################################

return script
