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

local alert_list_download_succeeded = classes.class(alert)

-- ##############################################

alert_list_download_succeeded.meta = {
   alert_key = other_alert_keys.alert_list_download_succeeded,
   i18n_title = "alerts_dashboard.list_download_succeeded",
   icon = "fas fa-fw fa-sticky-note",
   entities = {
      alert_entities.system
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param list_name The name of the succeeded list as string
-- @return A table with the alert built
function alert_list_download_succeeded:init(list_name)
   -- Call the parent constructor
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
