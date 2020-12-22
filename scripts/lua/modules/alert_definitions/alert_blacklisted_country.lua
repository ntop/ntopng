--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_blacklisted_country = classes.class(alert)

-- ##############################################

alert_blacklisted_country.meta = {
   status_key = status_keys.ntopng.status_blacklisted_country,
   alert_key = alert_keys.ntopng.alert_blacklisted_country,
   i18n_title = "alerts_dashboard.blacklisted_country",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param cli_country ISO 3166-1 alpha-2 client country code
-- @param srv_country ISO 3166-1 alpha-2 server country code
-- @param cli_blacklisted Boolean indicating whether the client belongs to a blacklisted country
-- @param srv_blacklisted Boolean indicating whether the server belongs to a blacklisted country
-- @return A table with the alert built
function alert_blacklisted_country:init(cli_country, srv_country, cli_blacklisted, srv_blacklisted)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
	 cli_country = cli_country,
	 srv_country = srv_country,
	 cli_blacklisted = cli_blacklisted,
	 srv_blacklisted = srv_blacklisted,
   }
end

-- #######################################################

function alert_blacklisted_country.format(ifid, alert, alert_type_params)
   if not alert_type_params then
      return i18n("alerts_dashboard.blacklisted_country")
   end

   if alert_type_params["cli_blacklisted"] and alert_type_params["srv_blacklisted"] then
      return(i18n("alerts_dashboard.client_and_server_countries_blacklisted", {
         cli_country = alert_type_params["cli_country"],
         srv_country = alert_type_params["srv_country"],
      }))
   elseif alert_type_params["srv_blacklisted"] then
      return(i18n("alerts_dashboard.server_country_blacklisted", {country = alert_type_params["srv_country"]}))
   elseif alert_type_params["cli_blacklisted"] then
      return(i18n("alerts_dashboard.client_country_blacklisted", {country = alert_type_params["cli_country"]}))
   end

   return i18n("alerts_dashboard.blacklisted_country")
end

-- #######################################################

return alert_blacklisted_country
