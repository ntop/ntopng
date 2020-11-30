--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param network The string CIDR of the ghost network
-- @return A table with the alert built
local function createGhostNetwork(alert_severity, alert_granularity, network)
   local built = {
      alert_severity = alert_severity,
      alert_granularity = alert_granularity,
      alert_subtype = network,
      alert_type_params = {
      },
   }

   return built
end

-- #######################################################

local function ghostNetworkFormatter(ifid, alert, info)
  return(i18n("alerts_dashboard.ghost_network_detected_description", {
    network = alert.alert_subtype,
    entity = getInterfaceName(ifid),
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=".. ifid .."&page=networks",
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_ghost_network,
  i18n_title = "alerts_dashboard.ghost_network_detected",
  i18n_description = ghostNetworkFormatter,
  icon = "fas fa-ghost",
  creator = createGhostNetwork,
}
