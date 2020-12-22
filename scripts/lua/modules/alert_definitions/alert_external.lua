--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local status_keys = require "flow_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_external = classes.class(alert)

-- ##############################################

alert_external.meta = {
   status_key = status_keys.ntopng.status_external_alert,
   alert_key = alert_keys.ntopng.alert_external,
   i18n_title = "alerts_dashboard.external_alert",
   icon = "fas fa-eye",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param info A generic table decoded from a JSON originated at the external alert source
-- @return A table with the alert built
function alert_external:init(info)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = info
end

-- #######################################################

local function formatIDSAlert(alert)
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

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_external.format(flowstatus_info)
   local res = i18n("alerts_dashboard.external_alert")

   if not flowstatus_info then
      return res
   end

   -- Available fields:
   -- flowstatus_info.source (e.g. suricata)
   -- flowstatus_info.severity_id (custom severity)
   -- flowstatus_info.alert (alert metadata)

   if flowstatus_info.source == "suricata" then
      res = formatIDSAlert(flowstatus_info.alert)
   end

   return res
end

-- #######################################################

return alert_external
