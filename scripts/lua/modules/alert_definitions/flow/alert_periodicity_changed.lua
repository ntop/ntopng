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
-- @return A table with the alert built
function alert_periodicity_changed:init()
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
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
   local flow_infos = {
      host = alert["cli_ip"],
      l7proto = ternary(tonumber(alert["l7_proto"]) ~= 0, alert["l7_proto"], alert["l7_master_proto"]),
      vlan_id = alert["vlan_id"]
   }
   local graph_map_utils = require("graph_map_utils")

   if alert.json then
      info = json.decode(alert["json"])
      if not isEmptyString(info["info"]) then
         info = "[" .. info["info"] .. "]"
      else
         info = ""
      end   
   end

   href = '<a href="' .. graph_map_utils.getMapUrl(flow_infos, interface.getId(), 'periodicity_map', 'graph') .. '"><i class="fas fa-lg fa-clock"></i></a>'

   if alert_type_params.is_periodic then
      return(i18n("alerts_dashboard.periodicity_is_periodic_descr", { info = info, href = href }))
   elseif alert_type_params.is_aperiodic then
      return(i18n("alerts_dashboard.periodicity_is_aperiodic_descr", { info = info, href = href }))
   else
      return(i18n("alerts_dashboard.periodicity_changed_descr", { info = info, href = href }))
   end
end

-- #######################################################

return alert_periodicity_changed
