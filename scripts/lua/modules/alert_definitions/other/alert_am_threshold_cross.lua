--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local format_utils = require("format_utils")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_am_threshold_cross = classes.class(alert)

-- ##############################################

alert_am_threshold_cross.meta = {
   alert_key = other_alert_keys.alert_am_threshold_cross,
   i18n_title = "graphs.active_monitoring",
   icon = "fas fa-fw fa-exclamation",
   entities = {
      alert_entities.am_host,
   },
}

-- ##############################################

function alert_am_threshold_cross:init(value, threshold, ip, host, operator, unit)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      value = value,
      threshold = threshold,
      ip = ip,
      host = host,
      operator = operator,
      unit = unit
   }
end

-- #######################################################

function alert_am_threshold_cross.format(ifid, alert, alert_type_params)
   local msg
   local host = alert_type_params.host
   local numeric_ip = alert_type_params.ip
   local ip_label = host and host.label or numeric_ip

   if numeric_ip ~= host.host then
      numeric_ip = string.format("(%s)", numeric_ip)
   else
      numeric_ip = ""
   end

   if(alert_type_params.value == 0) then -- host unreachable
      if(alert_type_params.alt_i18n) then
	 -- The measurement may have defined a custom message via unreachable_alert_i18n
	 msg = i18n(alert_type_params.alt_i18n,
		    {host = ip_label,
		     numeric_ip = numeric_ip}) or alert_type_params.alt_i18n
      end

      -- Fallback
      if isEmptyString(msg) then
	 msg = i18n("alert_messages.ping_host_unreachable_v3",
		 {host = ip_label,
		  numeric_ip = numeric_ip})
      end
   else -- host too slow
      if alert_type_params.operator == "lt" then
	 i18n_s = "alert_messages.measurement_too_low_msg"
      else
	 i18n_s = "alert_messages.measurement_too_high_msg"
      end

      local unit = "active_monitoring_stats.msec"

      if alert_type_params.unit then
	 unit = alert_type_params.unit
      end

      unit = i18n(unit) or unit

      if unit == "%" then
	 unit = "%%"
      end

      local msg_table = {
	 host = ip_label,
	 numeric_ip = numeric_ip,
	 am_value = format_utils.round(alert_type_params.value, 2),
	 threshold = alert_type_params.threshold,
	 unit = unit,
      }

      msg = i18n(i18n_s, msg_table)
   end

   return msg
end

-- #######################################################

return alert_am_threshold_cross
