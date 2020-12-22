--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local status_keys = require "flow_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_zero_tcp_window = classes.class(alert)

-- ##############################################

alert_zero_tcp_window.meta = {
   status_key = status_keys.ntopng.status_zero_tcp_window,
   alert_key = alert_keys.ntopng.alert_zero_tcp_window,
   i18n_title = "zero_tcp_window.zero_tcp_window_title",
   icon = "fas fa-arrow-circle-up",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_zero_tcp_window:init(is_client, is_server)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      is_client = is_client,
      is_server = is_server,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_zero_tcp_window.format(ifid, alert, alert_type_params)
   if alert_type_params then
      if alert_type_params.is_client then
	 return i18n("zero_tcp_window.status_zero_tcp_window_description_c2s")
      elseif alert_type_params.is_server then
	 return i18n("zero_tcp_window.status_zero_tcp_window_description_s2c")
      end
   end

   return i18n("zero_tcp_window.status_zero_tcp_window_description")
end

-- #######################################################

return alert_zero_tcp_window
