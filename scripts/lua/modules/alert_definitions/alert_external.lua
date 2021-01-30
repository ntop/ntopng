--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local external_alert = classes.class(alert)

-- ##############################################

external_alert.meta = {
   alert_key = alert_keys.ntopng.alert_external,
   status_key = status_keys.ntopng.status_external_alert,
   i18n_title = "alerts_dashboard.external_alert",
   icon = "fas fa-eye",
   status_keep_increasing_scores = true, -- Every time an external alert is set, scores are increased accordingly
}

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A generic table decoded from a JSON originated at the external alert source
-- @return A table with the alert built
function external_alert:init(info)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = info
end

-- #######################################################

local function formatIDSAlert(alert)
   local alert_consts = require "alert_consts"

   local signature = (alert and alert.signature)
   local category = (alert and alert.category)
   local signature_info = (signature and signature:split(" "));
   local maker = (signature_info and table.remove(signature_info, 1))
   local scope = (signature_info and table.remove(signature_info, 1))
   local msg = (signature_info and table.concat(signature_info, " "))
   if maker and alert_consts.ids_rule_maker[maker] then
      maker = alert_consts.ids_rule_maker[maker]
   end
   return i18n("flow_details.ids_alert", { scope=scope, msg=msg, maker=maker })
end

-- #######################################################

function external_alert.format(ifid, alert, alert_type_params)
   local res = i18n("alerts_dashboard.external_alert")

   if not alert_type_params then
      return res
   end

   -- Available fields:
   -- alert_type_params.source (e.g. suricata)
   -- alert_type_params.severity_id (custom severity)
   -- alert_type_params.alert (alert metadata)

   if alert_type_params.source == "suricata" then
      res = formatIDSAlert(alert_type_params.alert)
   end

   return res
end

-- #######################################################

return external_alert
