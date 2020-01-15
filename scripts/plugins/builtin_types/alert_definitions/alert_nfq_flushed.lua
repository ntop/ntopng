--
-- (C) 2019-20 - ntop.org
--

local function nfwFlushedFormatter(ifid, alert, info)
  return(i18n("alert_messages.nfq_flushed", {
    name = info.ifname, pct = info.pct,
    tot = info.tot, dropped = info.dropped,
    url = ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=" .. ifid,
  }))
end

-- #######################################################

return {
  i18n_title = "alerts_dashboard.nfq_flushed",
  i18n_description = nfwFlushedFormatter,
  icon = "fas fa-angle-double-down",
}
