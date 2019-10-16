--
-- (C) 2019 - ntop.org
--

local function ghostNetworkFormatter(ifid, alert, info)
  return(i18n("alerts_dashboard.ghost_network_detected_description", {
    network = alert.alert_subtype,
    entity = getInterfaceName(ifid),
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=".. ifid .."&page=networks",
  }))
end

-- #######################################################

return {
  alert_id = 47,
  i18n_title = "alerts_dashboard.ghost_network_detected",
  i18n_description = ghostNetworkFormatter,
  icon = "fa-snapchat-ghost",
}
