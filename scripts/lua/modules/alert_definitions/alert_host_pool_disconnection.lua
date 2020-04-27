--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

-- #######################################################

local function poolDisconnectionFormat(ifid, alert, info)
  return(i18n("alert_messages.host_pool_has_disconnected", {
    pool = info.pool,
    url = getHostPoolUrl(alert.alert_entity_val),
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_host_pool_disconnection,
  i18n_title = "alerts_dashboard.host_pool_disconnection",
  i18n_description = poolDisconnectionFormat,
  icon = "fas fa-sign-out",
  creator = alert_creators.createPoolConnectionDisconnection,
}
