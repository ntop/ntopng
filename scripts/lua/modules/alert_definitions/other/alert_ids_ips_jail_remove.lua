--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_ids_ips_jail_remove = classes.class(alert)

-- ##############################################

alert_ids_ips_jail_remove.meta = {
  alert_key = other_alert_keys.alert_ids_ips_jail_remove,
  i18n_title = "alerts_dashboard.alert_ids_ips_jail_remove",
  icon = "fas fa-fw fa-user",
  entities = {
    alert_entities.interface
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param host The host that has been added to the jailed hosts pool
-- @param when The timestamp when the host has been added to the jailed hosts pool
-- @return A table with the alert built
function alert_ids_ips_jail_remove:init(host, when)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      host = host,
      when = when
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_ids_ips_jail_remove.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")

  return(i18n("alert_messages.alert_ids_ips_jail_remove", {host = alert_type_params.host, when = formatEpoch(alert_type_params.when)}))
end

-- #######################################################

return alert_ids_ips_jail_remove
