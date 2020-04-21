--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatBlacklistedFlow(info)
   if not info then
      return i18n("alerts_dashboard.blacklisted_country")
   end

   if info["cli_blacklisted"] and info["srv_blacklisted"] then
      return(i18n("alerts_dashboard.client_and_server_countries_blacklisted", {
         cli_country = info["cli_country"],
         srv_country = info["srv_country"],
      }))
   elseif info["srv_blacklisted"] then
      return(i18n("alerts_dashboard.server_country_blacklisted", {country = info["srv_country"]}))
   elseif info["cli_blacklisted"] then
      return(i18n("alerts_dashboard.client_country_blacklisted", {country = info["cli_country"]}))
   end

   return i18n("alerts_dashboard.blacklisted_country")
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_blacklisted_country,
  alert_severity = alert_consts.alert_severities.error,
  alert_type = alert_consts.alert_types.alert_blacklisted_country,
  i18n_title = "alerts_dashboard.blacklisted_country",
  i18n_description = formatBlacklistedFlow
}
