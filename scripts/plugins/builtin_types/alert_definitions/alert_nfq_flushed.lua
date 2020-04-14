--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

local function nfwFlushedFormatter(ifid, alert, info)
  return(i18n("alert_messages.nfq_flushed", {
    name = info.ifname, pct = info.pct,
    tot = info.tot, dropped = info.dropped,
    url = ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=" .. ifid,
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_nfq_flushed,
  i18n_title = "alerts_dashboard.nfq_flushed",
  i18n_description = nfwFlushedFormatter,
  icon = "fas fa-angle-double-down",
}
