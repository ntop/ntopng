--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #################################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param list_name The name of the succeeded list as string
-- @return A table with the alert built
local function createListDownloadSucceededType(alert_severity, list_name)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 name = list_name
      }
   }

   return built
end

-- #################################################################

return {
  alert_key = alert_keys.ntopng.alert_list_download_succeeded,
  i18n_title = "alerts_dashboard.list_download_succeeded",
  i18n_description = "category_lists.download_succeeded",
  icon = "fas fa-sticky-note",
  creator = createListDownloadSucceededType,
}
