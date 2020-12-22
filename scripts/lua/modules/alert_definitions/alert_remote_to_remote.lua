--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local json = require("dkjson")
local status_keys = require "flow_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_remote_to_remote = classes.class(alert)

-- ##############################################

alert_remote_to_remote.meta = {
   status_key = status_keys.ntopng.status_remote_to_remote,
   alert_key = alert_keys.ntopng.alert_remote_to_remote,
   i18n_title = "alerts_dashboard.remote_to_remote",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_remote_to_remote:init(server_ip)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      server_ip = server_ip
   }
end

-- #######################################################

function alert_remote_to_remote.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   local entity = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(alert["alert_entity"]), alert["alert_entity_val"])

   return i18n("alert_messages.remote_to_remote", {
        entity = entity,
        host_category = format_utils.formatAddressCategory((json.decode(alert.alert_json)).alert_generation.host_info),
   })
end

-- #######################################################

return alert_remote_to_remote
