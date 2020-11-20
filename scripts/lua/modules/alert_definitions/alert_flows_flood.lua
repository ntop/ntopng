--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"
local format_utils = require "format_utils"

-- #######################################################

local function formatFlowsFlood(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local value = threshold_info.value

  if(value == nil) then value = 0 end
  
  if(alert.alert_subtype == "flow_flood_attacker") then
    return i18n("alert_messages.flow_flood_attacker", {
      entity = firstToUpper(entity),
      host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
      value = string.format("%u", math.ceil(value)),
      threshold = threshold_info.threshold,
    })
  else
    return i18n("alert_messages.flow_flood_victim", {
      entity = firstToUpper(entity),
      host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
      value = string.format("%u", math.ceil(value)),
      threshold = threshold_info.threshold,
    })
  end
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_flows_flood,
  i18n_title = "alerts_dashboard.flows_flood",
  i18n_description = formatFlowsFlood,
  icon = "fas fa-life-ring",
  creator = alert_creators.createThresholdCross,
}
