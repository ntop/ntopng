--
-- (C) 2020 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- Called by flow.triggerStatus() in zero_tcp_window.lua 
local function createZeroTcpWindow(is_client, is_server)
   local zero_tcp_window_type = {
      alert_type_params = {
	 is_client = is_client,
	 is_server = is_server,
      }
   }
   
   return zero_tcp_window_type
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_zero_tcp_window,
  i18n_title = "zero_tcp_window.alert_zero_tcp_window_title",
  i18n_description = "zero_tcp_window.alert_zero_tcp_window_description",
  icon = "fas fa-arrow-circle-up",
  creator = createZeroTcpWindow,
}
