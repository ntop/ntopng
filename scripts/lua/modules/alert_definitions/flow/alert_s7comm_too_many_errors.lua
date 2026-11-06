--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
local json = require "dkjson"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_s7comm_too_many_errors = classes.class(alert)

-- ##############################################

alert_s7comm_too_many_errors.meta = {
   alert_key = flow_alert_keys.flow_alert_s7comm_too_many_errors,
   i18n_title = "flow_checks.s7comm_too_many_errors",
   icon = "fas fa-fw fa-industry",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.impact,
      mitre_technique = mitre.technique.data_manipulation,
      mitre_id = "T1565"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_s7comm_too_many_errors:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_s7comm_too_many_errors.format(ifid, alert, alert_type_params)
   local info = alert_type_params

   -- Notifications carry the alert params nested in alerts[<alert_key>]
   if not info.num_errors and info.alerts then
      info = info.alerts[tostring(flow_alert_keys.flow_alert_s7comm_too_many_errors)] or info
   end

   local rsp = (info.num_errors or i18n("unknown")) .. " Errors"

   -- tprint(alert_type_params)

   return(rsp)
end

-- #######################################################

return alert_s7comm_too_many_errors
