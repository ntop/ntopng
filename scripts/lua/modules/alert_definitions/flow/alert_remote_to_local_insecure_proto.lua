--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_remote_to_local_insecure_proto = classes.class(alert)

-- ##############################################

alert_remote_to_local_insecure_proto.meta = {
   alert_key = flow_alert_keys.flow_alert_remote_to_local_insecure_proto,
   i18n_title = "alerts_dashboard.remote_to_local_insecure_proto",
   icon = "fas fa-fw fa-exclamation",

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_remote_to_local_insecure_proto:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_remote_to_local_insecure_proto.format(ifid, alert, alert_type_params)
   return i18n("alert_messages.remote_to_local_insecure_proto", {
		  ndpi_breed = formatBreed(alert_type_params.ndpi_breed_name),
		  ndpi_category = alert_type_params.ndpi_category_name,
   })
end

-- #######################################################

return alert_remote_to_local_insecure_proto
