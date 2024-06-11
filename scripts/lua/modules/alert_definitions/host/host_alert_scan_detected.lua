--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_scan_detected = classes.class(alert)

-- ##############################################

host_alert_scan_detected.meta = {
  alert_key = host_alert_keys.host_alert_scan_detected, -- host_alert_keys.lua
  i18n_title = "alerts_dashboard.scan_detected",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,

   -- Mitre Att&ck Matrix values
   mitre_tactic = "mitre.tactic.reconnaissance",
   mitre_tecnique = "mitre.tecnique.active_scanning",
   mitre_ID = "T1595",
}

-- ##############################################

function host_alert_scan_detected:init(metric, value, operator, threshold)
   -- Call the parent constructor
   self.super:init()
   
   self.alert_type_params.value = value
   self.alert_type_params.operator = operator
   self.alert_type_params.threshold = threshold
   self.alert_type_params.metric = metric
end

-- #######################################################

function host_alert_scan_detected.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  
  if (alert_type_params.is_rx_only) then
    return i18n("alert_messages.rx_scan_detected",{
      entity = entity,
      as_server = alert_type_params.as_server,
      num_server_ports = alert_type_params.num_server_ports,
    })
  else
    local i18n_key
    local formatted_alert_type_params = alert_creators.createThresholdCross(
                                      alert_type_params.metric, 
                                      alert_type_params.value, 
                                      alert_type_params.operator, 
                                      alert_type_params.threshold)

    return i18n("alert_messages.scan_detected", {
      entity = entity,
      value = string.format("%u", math.ceil(formatted_alert_type_params.value or 0)),
      threshold = formatted_alert_type_params.threshold or 0,
    })
  end
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_scan_detected.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- TODO
   
   return res
end

-- #######################################################

return host_alert_scan_detected
