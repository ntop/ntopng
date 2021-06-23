--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_nfq_flushed = classes.class(alert)

-- ##############################################

alert_nfq_flushed.meta = {
  alert_key = other_alert_keys.alert_nfq_flushed,
  i18n_title = "alerts_dashboard.nfq_flushed",
  icon = "fas fa-fw fa-angle-double-down",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param ifname The name of the interface
-- @param ptc The percentage of NFQ fill level
-- @param tot Thee total number of packets in the NFQ
-- @param dropped The number of packets dropped
-- @return A table with the alert built
function alert_nfq_flushed:init(ifname, pct, tot, dropped)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    ifname = ifname,
    pct = pct,
    tot = tot,
    dropped = dropped,
   }
end

-- #######################################################

function alert_nfq_flushed.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.nfq_flushed", {
    name = alert_type_params.ifname, pct = alert_type_params.pct,
    tot = alert_type_params.tot, dropped = alert_type_params.dropped,
    url = ntop.getHttpPrefix().."/lua/if_stats.lua?ifid=" .. ifid,
  }))
end

-- #######################################################

return alert_nfq_flushed
