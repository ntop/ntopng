--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local classes = require "classes"
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_disk_space_low = classes.class(alert)

-- ##############################################

alert_disk_space_low.meta = {
  alert_key = other_alert_keys.alert_disk_space_low,
  i18n_title = "alerts_dashboard.disk_space_low",
  icon = "fas fa-fw fa-hdd",
  entities = {
     alert_entities.system,
  },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param volume Label for the monitored volume
-- @param used_perc Percentage of used disk space on volume
-- @param avail_bytes Number of bytes still available on volume
-- @param threshold The threshold compared with used_perc
-- @return A table with the alert built
function alert_disk_space_low:init(volume, used_perc, avail_bytes, threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      volume = volume,
      used_perc = used_perc,
      avail_bytes = avail_bytes,
      edge = threshold,
   }
end

-- #######################################################

-- @brief Format an alert
-- @param ifid The interface id of the generated alert
-- @param alert The alert description table
-- @param alert_type_params Table alert_type_params as built in the :init method
-- @return A human-readable string
function alert_disk_space_low.format(ifid, alert, alert_type_params)
   local format_utils = require "format_utils"

   return(i18n("alert_messages.disk_space_low", {
      volume = alert_type_params.volume,
      used_perc = string.format("%.1f", alert_type_params.used_perc or 0),
      threshold = alert_type_params.edge or 0,
      avail = format_utils.bytesToSize(alert_type_params.avail_bytes or 0),
   }))
end

-- #######################################################

return alert_disk_space_low
