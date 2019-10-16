--
-- (C) 2019 - ntop.org
--

local function formatMisconfiguredApp(ifid, alert, threshold_info)
  local entity = formatAlertEntity(ifid, alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

  if alert.alert_subtype == "too_many_flows" then
    return(i18n("alert_messages.too_many_flows", {iface=entity, option="--max-num-flows/-X"}))
  elseif alert.alert_subtype == "too_many_hosts" then
    return(i18n("alert_messages.too_many_hosts", {iface=entity, option="--max-num-hosts/-x"}))
  else
    return("Unknown app misconfiguration: " .. (alert.alert_subtype or ""))
  end
end

-- #######################################################

return {
  alert_id = 15,
  i18n_title = "alerts_dashboard.misconfigured_app",
  icon = "fa-cog",
  i18n_description = formatMisconfiguredApp,
}
