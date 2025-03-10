--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local classes = require "classes"
local alert = require "alert"
local mitre = require "mitre_utils"

-- ##############################################

local host_alert_scan = classes.class(alert)

-- ##############################################

host_alert_scan.meta = {
  alert_key = host_alert_keys.host_alert_scan,
  i18n_title = "alerts_dashboard.scan_title",
  icon = "fas fa-exclamation-triangle",

   -- Mitre Att&ck Matrix values
  mitre_values = {},
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_scan:init(ifid, attacker, victim, num_victims, attack)
   self.super:init()
   self.alert_type_params = {
     ifid = ifid,
     attacker = attacker,
     victim = victim,
     num_victims = num_victims,
     attack = attack
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_scan.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local attacker = alert_consts.formatHostAlert(ifid, alert_type_params.attacker, alert["vlan_id"])
  local victim = alert_consts.formatHostAlert(ifid, alert_type_params.victim, alert["vlan_id"])
  if alert_type_params.attack == "Service" then
    return i18n("alert_messages.host_alert_scan_service", { 
      attacker = attacker,
      victim = victim,
      num_victims = alert_type_params.num_victims,
      attack = alert_type_params.attack
    })
  elseif alert_type_params.attack == "Network" then
    return i18n("alert_messages.host_alert_scan_network", { 
      attacker = attacker,
      victim = victim,
      num_victims = alert_type_params.num_victims,
      attack = alert_type_params.attack
    })
  elseif alert.is_attacker == "1" then
    return i18n("alert_messages.host_alert_scan_port", { 
      attacker = attacker,
      victim = victim,
      num_victims = alert_type_params.num_victims,
      attack = alert_type_params.attack
    })
  else
    return i18n("alert_messages.host_alert_scan_port_victim", { 
      victim = victim,
      attacker = attacker,
      attack = alert_type_params.attack
    })
  end
end

-- #######################################################

return host_alert_scan
