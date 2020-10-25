local alert_keys = require "alert_keys"

local function createRetransmissions(alert_severity, retransmissions_info)

   local built = {
      alert_serverity = alert_severity,
      alert_type_params = retransmissions_info
   }

   return built
end

-- ########################################

return {
   alert_key = alert_keys.ntopng.alert_too_many_retransmissions,
   i18n_title = "Retransmissions alert",
   icon = "fas fa-exclamation",
   creator = createRetransmissions,
}
