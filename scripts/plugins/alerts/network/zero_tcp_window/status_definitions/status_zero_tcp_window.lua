--
-- (C) 2020 - ntop.org
--

local alert_keys = require "alert_keys"
local status_keys = require "flow_keys"
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"

-- #######################################################

local function formatZeroTcpWindow(info)
   if info then
      if info.is_client then
	 return i18n("zero_tcp_window.status_zero_tcp_window_description_c2s")
      elseif info.is_server then
	 return i18n("zero_tcp_window.status_zero_tcp_window_description_s2c")
      end
   end

   return i18n("zero_tcp_window.status_zero_tcp_window_description")
end


-- #######################################################

return {
   status_key = status_keys.ntopng.status_zero_tcp_window,
   alert_severity = alert_severities.warning,
   alert_type = alert_consts.alert_types.alert_zero_tcp_window,
   i18n_title = "zero_tcp_window.zero_tcp_window_title",
   i18n_description = formatZeroTcpWindow,
   icon = "fas fa-arrow-circle-up",
}
