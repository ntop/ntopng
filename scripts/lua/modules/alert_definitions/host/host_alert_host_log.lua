--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_host_log = classes.class(alert)

-- ##############################################

host_alert_host_log.meta = {
  alert_key = host_alert_keys.host_alert_host_log,
  i18n_title = "alerts_dashboard.host_log",
  icon = "fa fa-file-text-o",
}

-- ##############################################
-- @brief Prepare an alert table used to generate the alert
-- @param host The string with the name or ip address of the host
-- @return A table with the alert built
function host_alert_host_log:init(host, level, facility, message)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      host = host,
      facility = facility,
      message = message,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_host_log.format(ifid, alert, alert_type_params)
  local hostinfo = hostkey2hostinfo(alert.entity_val)

  return(i18n("alert_messages.host_log", {
    host = alert_type_params.host,
    url = getHostUrl(hostinfo["host"], hostinfo["vlan"]),
    facility = alert_type_params.facility,
    line = alert_type_params.message,
  }))
end

-- #######################################################

return host_alert_host_log
