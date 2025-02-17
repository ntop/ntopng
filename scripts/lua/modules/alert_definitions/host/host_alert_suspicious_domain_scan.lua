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

local host_alert_suspicious_domain_scan = classes.class(alert)

-- ##############################################

host_alert_suspicious_domain_scan.meta = {
  alert_key = host_alert_keys.host_alert_suspicious_domain_scan,
  i18n_title = "alerts_dashboard.suspicious_domain_scan_title",
  icon = "fas fa-exclamation-triangle",

   -- Mitre Att&ck Matrix values
  mitre_values = {
    -- mitre_tactic = 
    -- mitre_technique = 
    -- mitre_id = 
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_suspicious_domain_scan:init(ifid, victim, num_domains)
   self.super:init()
   self.alert_type_params = {
     ifid = ifid,
     victim = victim,
     domains = num_domains
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_suspicious_domain_scan.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local attacker = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  local victim = alert_consts.formatHostAlert(ifid, alert_type_params.victim, alert["vlan_id"])
 
  return i18n("alert_messages.host_alert_suspicious_domain_scan", { 
    attacker = attacker,
    domains = alert_type_params.domains,
    victim = victim
  })
end

-- #######################################################

return host_alert_suspicious_domain_scan
