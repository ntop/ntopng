--
-- (C) 2019-25 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local classes = require "classes"
local alert = require "alert"
local mitre = require "mitre_utils"

-- ##############################################

local host_alert_scan_realtime = classes.class(alert)

local alert_table = {
  [0] = "Incomplete Flows Scan",
  [1] = "RX-only Host Scan",
  [2] = "SYN Scan",
  [3] = "FIN Scan",
  [4] = "RST Scan"
}
-- ##############################################

host_alert_scan_realtime.meta = {
  alert_key = host_alert_keys.host_alert_scan_realtime,
  i18n_title = "alerts_dashboard.scan_realtime",
  icon = "fas fa-exclamation-triangle",

   -- Mitre Att&ck Matrix values
  mitre_values = {
    mitre_tactic = mitre.tactic.reconnaissance,
    mitre_technique = mitre.technique.active_scanning,
    mitre_id = "T1595"
  },
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_scan_realtime:init(ifid, client, attack)
  self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_scan_realtime.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  local i18n_key
  local alerts = ""
  for i, alert in ipairs(alert_type_params.alerts) do
    alerts = alerts .. alert_table[alert] .. ", "
  end
  alerts = string.sub(alerts, 1, -3)
  return i18n("alert_messages.scan_realtime",{
    entity = entity,
    alerts = alerts
  })
end

-- #######################################################

return host_alert_scan_realtime
