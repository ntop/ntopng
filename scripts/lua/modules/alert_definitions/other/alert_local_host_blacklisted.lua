--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_local_host_blacklisted = classes.class(alert)

-- ##############################################

alert_local_host_blacklisted.meta = {
   alert_key = other_alert_keys.alert_local_host_blacklisted,
   i18n_title = "alerts_dashboard.local_host_blacklisted",
   icon = "fas fa-fw fa-sticky-note",
   entities = {
      alert_entities.system
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param list_name The name of the succeeded list as string
-- @param host      IP address of the host found on blacklist
-- @return A table with the alert built
function alert_local_host_blacklisted:init(list_name, host)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      name = list_name, host = host
   }
end

-- #######################################################

function alert_local_host_blacklisted.format(ifid, alert, alert_type_params)
   return i18n("category_lists.local_host_blacklisted", {name = alert_type_params.name, host = alert_type_params.host})
end

-- #######################################################

return alert_local_host_blacklisted
