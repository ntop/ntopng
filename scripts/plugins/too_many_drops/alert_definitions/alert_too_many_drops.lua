--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function formatTooManyPacketDrops(ifid, alert, threshold_info)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local max_drop_perc = threshold_info.threshold or 0

  return(i18n("alert_messages.too_many_drops", {iface = entity, max_drops = max_drop_perc}))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_too_many_drops,
  i18n_title = "alerts_dashboard.too_many_drops",
  icon = "fas fa-tint",
  i18n_description = formatTooManyPacketDrops,
}
