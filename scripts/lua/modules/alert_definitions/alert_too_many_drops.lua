--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param drops The number of dropped packets
-- @param drop_perc The percentage of dropped packets with reference to the total number of packets (recevied + dropped)
-- @param threshold A number indicating the threshold compared with `drop_perc`
-- @return A table with the alert built
local function createTooManyDrops(alert_severity, alert_granularity, drops, drop_perc, threshold)
   return({
	 alert_severity = alert_severity,
	 alert_granularity = alert_granularity,
	 alert_type_params = {
	    drops = drops, drop_perc = drop_perc, edge = threshold,
	 },
   })
end

-- #######################################################

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
  creator = createTooManyDrops
}
