--
-- (C) 2019 - ntop.org
--

local function formatTooManyPacketDrops(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])
  local max_drop_perc = threshold_info.edge or 0

  return(i18n("alert_messages.too_many_drops", {iface = entity, max_drops = max_drop_perc}))
end

-- #######################################################

return {
  alert_id = 16,
  i18n_title = "alerts_dashboard.too_many_drops",
  icon = "fa-tint",
  i18n_description = formatTooManyPacketDrops,
}
