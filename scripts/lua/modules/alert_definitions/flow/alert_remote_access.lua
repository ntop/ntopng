--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- require "lua_utils"

-- ##############################################

local alert_remote_access = classes.class(alert)

-- ##############################################

alert_remote_access.meta = {
   alert_key  = flow_alert_keys.flow_alert_remote_access,
   i18n_title = "alerts_dashboard.remote_access_title",
   icon = "fas fa-fw fa-info",

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.initial_access,
      mitre_tecnique = mitre.tecnique.ext_remote_services,
      mitre_id = "T1133"
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_remote_access:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_remote_access.format(ifid, alert, alert_type_params)
   local now = os.time()
   local tstamp_end = alert["tstamp_end"] or now
   local time = tstamp_end - alert["tstamp"]

   if time == 0 then
      time = "< 1"
   else
      time = secondsToTime(time)
   end

   return (i18n("alerts_dashboard.remote_access_alert_descr", { time = time }))
end

-- #######################################################

return alert_remote_access
