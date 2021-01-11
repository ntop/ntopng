--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_list_download_failed = classes.class(alert)

-- ##############################################

alert_list_download_failed.meta = {
   alert_key = alert_keys.ntopng.alert_list_download_failed,
   i18n_title = "alerts_dashboard.list_download_failed",
   icon = "fas fa-sticky-note",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param list_name The name of the failed list as string
-- @param last_error The string of the error which caused the failure
-- @return A table with the alert built
function alert_list_download_failed:init(list_name, last_error)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      name = list_name,
      err = last_error,
      url = ntop.getHttpPrefix().."/lua/admin/edit_category_lists.lua"
   }
end

-- #######################################################

function alert_list_download_failed.format(ifid, alert, alert_type_params)
   return i18n("category_lists.error_occurred",
	       {
		  url = alert_type_params.url,
		  name = alert_type_params.name,
		  err = alert_type_params.err
	       }
   )
end

-- #######################################################

return alert_list_download_failed
