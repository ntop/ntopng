--
-- (C) 2019-20 - ntop.org
--

-- #######################################################

local alert_keys = require "alert_keys"
local format_utils = require "format_utils"

-- #######################################################

local function formatRemoteToRemoteMessage(ifid, alert, remote_to_remote_info)
   local alert_consts = require("alert_consts")
   local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

   return i18n("alert_messages.remote_to_remote", {
        entity = entity,
        host_category = format_utils.formatAddressCategory(alert.host_info),
   })
end

-- #######################################################

return {
   alert_key = alert_keys.ntopng.alert_remote_to_remote,
   i18n_title = "alerts_dashboard.remote_to_remote",
   i18n_description = formatRemoteToRemoteMessage,
   icon = "fas fa-exclamation",
}
