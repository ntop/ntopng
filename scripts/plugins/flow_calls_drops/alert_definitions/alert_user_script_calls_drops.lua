--
-- (C) 2019-20 - ntop.org
--

local function formatUserScriptsCallsDrops(ifid, alert, alert_info)
  if(alert.alert_subtype == "flow") then
    return(i18n("alerts_dashboard.flow_user_scripts_calls_drops_description", {
      num_drops = alert_info.drops,
      url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=callbacks&tab=flows&ifid=" .. string.format("%d", ifid),
    }))
  end

  return("")
end

-- #######################################################

return {
  alert_id = 52,
  i18n_title = "alerts_dashboard.user_scripts_calls_drops",
  icon = "fa-tint",
  i18n_description = formatUserScriptsCallsDrops,
}
