--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local format_utils = require "format_utils"
local json = require("dkjson")
local status_keys = require "status_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_remote_to_local_insecure_proto = classes.class(alert)

-- ##############################################

alert_remote_to_local_insecure_proto.meta = {
   status_key = status_keys.ntopng.status_remote_to_local_insecure_proto,
   alert_key = alert_keys.ntopng.alert_remote_to_local_insecure_proto,
   i18n_title = "alerts_dashboard.remote_to_local_insecure_proto",
   icon = "fas fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_remote_to_local_insecure_proto:init(proto, category_name, breed_or_category)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      proto = proto,
      category_name = category_name,  
      breed_or_category = breed_or_category,
   }
end

-- #######################################################

function alert_remote_to_local_insecure_proto.format(ifid, alert, alert_type_params)
   if breed_or_category == false then
        return i18n("alert_messages.remote_to_local_insecure_proto_category", {
            proto = alert_type_params.category_name,
            proto_id = alert_type_params.proto,
        })
   else
        return i18n("alert_messages.remote_to_local_insecure_proto_breed", {
            proto = alert_type_params.proto,
        })
   end

   
end

-- #######################################################

return alert_remote_to_local_insecure_proto
