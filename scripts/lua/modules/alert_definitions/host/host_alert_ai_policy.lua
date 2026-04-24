--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local classes = require "classes"
local alert   = require "alert"

-- ##############################################

local host_alert_ai_policy = classes.class(alert)

-- ##############################################

host_alert_ai_policy.meta = {
  alert_key  = host_alert_keys.host_alert_ai_policy,
  i18n_title = "alerts_dashboard.ai_policy",
  icon       = "fas fa-fw fa-robot",
  has_attacker = true,
}

-- ##############################################

function host_alert_ai_policy:init(message)
   self.super:init()
   self.alert_type_params = { message = message }
end

-- ##############################################

function host_alert_ai_policy.format(ifid, alert, alert_type_params)
   return (alert_type_params and alert_type_params["message"]) or ""
end

-- ##############################################

function host_alert_ai_policy.filter_to_past_flows(ifid, alert, alert_type_params)
   local res      = {}
   local host_key = hostinfo2hostkey({ ip = alert["ip"], vlan = alert["vlan_id"] })

   if alert["is_client"] == true or alert["is_client"] == "1" then
      res["cli_ip"] = host_key
   elseif alert["is_server"] == true or alert["is_server"] == "1" then
      res["srv_ip"] = host_key
   end

   return res
end

-- ##############################################

return host_alert_ai_policy
