--
-- (C) 2019 - ntop.org
--

local function formatActiveFlowsAnomaly(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
  local alert_consts = require("alert_consts")

  if entity_info.anomalies ~= nil then
    if(alert_key == "num_active_flows_as_client") and (entity_info.anomalies.num_active_flows_as_client) then
      local anomaly_info = entity_info.anomalies.num_active_flows_as_client

      return string.format("%s has an anomalous number of active client flows [current_flows=%u][anomaly_index=%u]",
        firstToUpper(alert_consts.formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
        anomaly_info.value, anomaly_info.anomaly_index)
    elseif(alert_key == "num_active_flows_as_server") and (entity_info.anomalies.num_active_flows_as_server) then
      local anomaly_info = entity_info.anomalies.num_active_flows_as_server

      return string.format("%s has an anomalous number of active server flows [current_flows=%u][anomaly_index=%u]",
        firstToUpper(alert_consts.formatAlertEntity(ifid, entity_type, entity_value, entity_info)),
        anomaly_info.value, anomaly_info.anomaly_index)
    end
  end

  return ""
end

-- #######################################################

return {
  alert_id = 30,
  i18n_title = "alerts_dashboard.active_flows_anomaly",
  icon = "fa-life-ring",
  i18n_description = formatActiveFlowsAnomaly,
}
