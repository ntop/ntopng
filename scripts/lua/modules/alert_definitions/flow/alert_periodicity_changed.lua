--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local json = require "dkjson"

-- ##############################################

local alert_periodicity_changed = classes.class(alert)

-- ##############################################

alert_periodicity_changed.meta = {
   alert_key = flow_alert_keys.flow_alert_periodicity_changed,
   i18n_title = "alerts_dashboard.alert_periodicity_update",
   icon = "fas fa-fw fa-arrows-alt-h",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A table containing the last lateral movement error, e.g.,
--                   {"event":"create","shost":"192.168.2.153","dhost":"224.0.0.68","dport":1968,"vlan_id":0,"l4":17,"l7":0,"first_seen":1602488355,"last_seen":1602488355,"num_uses":1}
-- @return A table with the alert built
function alert_periodicity_changed:init(last_error, created_or_removed)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      error_msg = last_error,
      created_or_removed = created_or_removed
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_periodicity_changed.format(ifid, alert, alert_type_params)
   -- Extracting info field
   local info = ""
   local href = ""

   if alert.json then
      info = json.decode(alert["json"])
      if not isEmptyString(info["info"]) then
         info = "[" .. info["info"] .. "]"
      else
         info = ""
      end   
   end

   href = '<a href="/lua/pro/enterprise/periodicity_map.lua"><i class="fas fa-lg fa-clock"></i></a>'

   return(i18n("alerts_dashboard.periodicity_changed_descr", { info = info, href = href }))
end

-- #######################################################

return alert_periodicity_changed
