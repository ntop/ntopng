--
-- (C) 2019-20 - ntop.org
--

local json = require("dkjson")
local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"
local format_utils = require "format_utils"

-- ##############################################

local function formatSynFlood(ifid, alert, threshold_info)
  local alert_consts = require "alert_consts"
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  
  if(alert.alert_subtype == "syn_flood_attacker") then
    return i18n("alert_messages.syn_flood_attacker", {
      entity = firstToUpper(entity),
      host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  else
    return i18n("alert_messages.syn_flood_victim", {
      entity = firstToUpper(entity),
      host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
      value = string.format("%u", math.ceil(threshold_info.value)),
      threshold = threshold_info.threshold,
    })
  end
end

-- ##############################################

return {
  alert_key = alert_keys.ntopng.alert_tcp_syn_flood,
  i18n_title = "alerts_dashboard.tcp_syn_flood",
  i18n_description = formatSynFlood,
  icon = "fas fa-life-ring",
  creator = alert_creators.createThresholdCross,
}
