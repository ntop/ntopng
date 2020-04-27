--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param cli_country ISO 3166-1 alpha-2 client country code
-- @param srv_country ISO 3166-1 alpha-2 server country code
-- @param cli_blacklisted Boolean indicating whether the client belongs to a blacklisted country
-- @param srv_blacklisted Boolean indicating whether the server belongs to a blacklisted country
-- @return A table with the alert built
local function buildBlacklistedCountry(alert_severity, cli_country, srv_country, cli_blacklisted, srv_blacklisted)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 cli_country = cli_country,
	 srv_country = srv_country,
	 cli_blacklisted = cli_blacklisted,
	 srv_blacklisted = srv_blacklisted,
      }
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_blacklisted_country,
  i18n_title = "alerts_dashboard.blacklisted_country",
  icon = "fas fa-exclamation",
  builder = buildBlacklistedCountry,
}
