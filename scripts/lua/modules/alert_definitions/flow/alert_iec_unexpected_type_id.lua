--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
local json = require "dkjson"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"


-- ##############################################

local alert_iec_unexpected_type_id = classes.class(alert)

-- ##############################################

alert_iec_unexpected_type_id.meta = {
   alert_key = flow_alert_keys.flow_alert_iec_unexpected_type_id,
   i18n_title = "alerts_dashboard.iec_unexpected_type_id",
   icon = "fas fa-subway",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_iec_unexpected_type_id:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_iec_unexpected_type_id.format(ifid, alert, alert_type_params)
   local msg = json.decode(alert_type_params.error_msg)

   local rsp = "[CauseTX: "..msg.cause_tx.."][TypeId: "..msg.type_id.."][ASDU: ".. msg.asdu.."][Negative: "

   if(msg.negatiive == false) then
      rsp = rsp .. "True]"
   else
      rsp = rsp .. "False]"
   end
   
   -- tprint(rsp)
   
   return(rsp)
end

-- #######################################################

return alert_iec_unexpected_type_id
