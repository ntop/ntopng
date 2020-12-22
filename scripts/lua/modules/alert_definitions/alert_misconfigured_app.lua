--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param alert_subtype A string with the subtype of the alert
-- @return A table with the alert built
local function createMisconfiguredApp(alert_severity, alert_granularity, alert_subtype)
   local built = {
      alert_severity = alert_severity,
      alert_subtype = alert_subtype,
      alert_granularity = alert_granularity,
      alert_type_params = {
      },
   }

   return built
end

-- #######################################################

local function formatMisconfiguredApp(ifid, alert, threshold_info)
  local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

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
  alert_key = alert_keys.ntopng.alert_misconfigured_app,
  i18n_title = "alerts_dashboard.misconfigured_app",
  icon = "fas fa-cog",
  i18n_description = formatMisconfiguredApp,
  creator = createMisconfiguredApp,
}
