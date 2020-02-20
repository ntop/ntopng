--
-- (C) 2019-20 - ntop.org
--

local function formatPeriodicActivityNotExecuted(ifid, alert, info)
  return(i18n("alert_messages.periodic_activity_not_executed", {
    script = alert.alert_entity_val,
    pending_since = format_utils.formatPastEpochShort(info.pending_since),
  }))
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.periodic_activity_not_executed",
  i18n_description = formatPeriodicActivityNotExecuted,
  icon = "fas fa-undo",
}
