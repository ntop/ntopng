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

local alert_list_download_succeeded = classes.class(alert)

-- ##############################################

alert_list_download_succeeded.meta = {
   alert_key = alert_keys.ntopng.alert_list_download_succeeded,
   i18n_title = "alerts_dashboard.list_download_succeeded",
   icon = "fas fa-sticky-note",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param list_name The name of the succeeded list as string
-- @return A table with the alert built
function alert_list_download_succeeded:init(list_name)
   -- Call the paren constructor
   self.super:init()

   self.alert_type_params = {
      name = list_name
   }
end

-- #######################################################

function alert_list_download_succeeded.format(ifid, alert, alert_type_params)
   return i18n("category_lists.download_succeeded", {name = alert_type_params.name})
end

-- #######################################################

return alert_list_download_succeeded
