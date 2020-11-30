--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param ifname The name of the interface
-- @param ptc The percentage of NFQ fill level
-- @param tot Thee total number of packets in the NFQ
-- @param dropped The number of packets dropped
-- @return A table with the alert built
local function createNfqFlushedType(alert_severity, ifname, pct, tot, dropped)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 ifname = ifname,
	 pct = pct,
	 tot = tot,
	 dropped = dropped,
      },
   }

   return built
end

-- #######################################################

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
  creator = createNfqFlushedType,
}
