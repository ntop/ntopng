--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")
local alert_severities = require "alert_severities"
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")

-- #################################################################

local script = {
   -- Script category
   category = user_scripts.script_categories.security, 

   default_enabled = true,
   
   -- NOTE: hooks defined below
   hooks = {},

   gui = {
      i18n_title = "flow_callbacks_config.remote_to_local_insecure_proto_title",
      i18n_description = "flow_callbacks_config.remote_to_local_insecure_proto_description",
   }
}

-- #################################################################

function script.hooks.protocolDetected(params)
   -- Is Remote to Local?
   if flow.isRemoteToLocal() then
      local flow_info = flow.getInfo()
      local unsafe = false
      local breed_or_category = false -- true -> breed and false -> category
      local flow_score = 100
      local srv_score = 5
      local cli_score, proto, category_name
      --Unsafe Protocol?
      if flow_info["proto.ndpi_breed"] then
         proto = flow_info["proto.ndpi_breed"]
         breed_or_category = true

         if proto == "Unsafe" then
            unsafe = true
            cli_score = 50
         elseif proto == "Potentially Dangerous" then
            unsafe = true
            cli_score = flow_consts.max_score // 2
         elseif proto == "Dangerous" then
            unsafe = true
            cli_score = flow_consts.max_score
         end

         goto trigger_alert
      end

      if flow_info["proto.ndpi_cat_id"] then
         proto = flow_info["proto.ndpi_cat_id"]
         breed_or_category = false

         if proto == 100 or proto == 102 then
            unsafe = true
            cli_score = flow_consts.max_score
            srv_score = 5
         end
      end

      ::trigger_alert::
      if unsafe then
         local alert = alert_consts.alert_types.alert_remote_to_local_insecure_proto.new(
            proto,
            category_name,
            breed_or_category
         )

         if cli_score >= (flow_consts.max_score // 2) then
            alert:set_severity(alert_severities.error)
         else
            alert:set_severity(alert_severities.warning)
         end

         alert:trigger_status(cli_score, srv_score, flow_score)
      end
   end
end

-- #################################################################

return script
