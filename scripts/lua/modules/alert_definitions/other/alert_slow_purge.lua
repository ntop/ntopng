--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_slow_purge = classes.class(alert)

-- ##############################################

alert_slow_purge.meta = {
  alert_key = other_alert_keys.alert_slow_purge,
  i18n_title = "alerts_dashboard.slow_purge",
  icon = "fas fa-fw fa-exclamation",
  entities = {
    alert_entities.system
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param idle Number of entries in state idle
-- @param idle_perc Fraction of entries in state idle, with reference to the total number of entries (idle + active)
-- @param threshold Threshold compared against idle_perc
-- @return A table with the alert built
function alert_slow_purge:init(idle, idle_perc, threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    idle = idle,
    idle_perc = idle_perc,
    edge = threshold,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_slow_purge.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["entity_id"]), alert["entity_val"])
  local max_idle_perc = format_utils.round(alert_type_params.edge or 0, 0)
  local actual_idle_perc = format_utils.round(alert_type_params.idle_perc or 0, 0)

  return(i18n("alert_messages.slow_purge", {
    iface = entity, idle = actual_idle_perc, max_idle = max_idle_perc,
    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. ifid .. "&page=internals",
  }))
end

-- #######################################################

return alert_slow_purge
