--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_builders = require "alert_builders"

-- #######################################################

local function poolConnectionFormat(ifid, alert, info)
  return(i18n("alert_messages.host_pool_has_connected", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_host_pool_connection,
  i18n_title = "alerts_dashboard.host_pool_connection",
  i18n_description = poolConnectionFormat,
  icon = "fas fa-sign-in",
  builder = alert_builders.buildPoolConnectionDisconnection,
}
