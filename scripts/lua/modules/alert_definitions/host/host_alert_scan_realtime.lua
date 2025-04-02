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

-- ##############################################

host_alert_scan_realtime.meta = {
  alert_key = host_alert_keys.host_alert_scan_realtime,
  i18n_title = "alerts_dashboard.scan_realtime",
  icon = "fas fa-exclamation-triangle",

   -- Mitre Att&ck Matrix values
  mitre_values = {},
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
  if alert_type_params.attack_type == 0 then
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
  elseif alert_type_params.attack_type == 1 then
    return i18n("alert_messages.rx_scan_detected",{
      entity = entity,
      as_server = alert_type_params.as_server,
      num_server_ports = alert_type_params.num_server_ports,
    })
  else
    if alert_type_params.attack_type == 2 then
      if alert_type_params.is_attacker then
        i18n_key = "alert_messages.syn_scan_attacker"
      else
        i18n_key = "alert_messages.syn_scan_victim"
      end
    elseif alert_type_params.attack_type == 3 then 
      if alert_type_params.is_attacker then
        i18n_key = "alert_messages.fin_scan_attacker"
      else
        i18n_key = "alert_messages.fin_scan_victim"
      end
    elseif alert_type_params.attack_type == 4 then
      if alert_type_params.is_attacker then
        i18n_key = "alert_messages.rst_scan_attacker"
      else
        i18n_key = "alert_messages.rst_scan_victim"
      end
    end
    return i18n(i18n_key, {
      entity = entity,
      value = string.format("%u", math.ceil(alert_type_params.value or 0)),
      threshold = alert_type_params.threshold or 0,
    })
  end
end

-- #######################################################

return host_alert_scan_realtime
