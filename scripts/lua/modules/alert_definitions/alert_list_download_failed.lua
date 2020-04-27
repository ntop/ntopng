--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #################################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param list_name The name of the failed list as string
-- @param last_error The string of the error which caused the failure
-- @return A table with the alert built
local function createListDownloadFailedType(alert_severity, list_name, last_error)
   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 name = list_name,
	 err = last_error
      }
   }

   return built
end

-- #################################################################

return {
  alert_key = alert_keys.ntopng.alert_list_download_failed,
  i18n_title = "alerts_dashboard.list_download_failed",
  i18n_description = "category_lists.error_occurred",
  icon = "fas fa-sticky-note",
  creator = createListDownloadFailedType,
}
