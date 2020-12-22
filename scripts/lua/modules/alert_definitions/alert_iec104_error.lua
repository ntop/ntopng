--
-- (C) 2019-20 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
local json = require "dkjson"
local format_utils = require "format_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"


-- ##############################################

local alert_iec104_error = classes.class(alert)

-- ##############################################

alert_iec104_error.meta = {
   alert_key = alert_keys.ntopng.alert_iec104_error,
   i18n_title = "alerts_dashboard.iec104_error",
   icon = "fas fa-subway",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param last_error A string with the lastest influxdb error
-- @return A table with the alert built
function alert_iec104_error:init(last_error)
   -- Call the paren constructor
   self.super:init()

   self.alert_type_params = {
      error_msg = last_error
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_iec104_error.format(ifid, alert, alert_type_params)
   local msg = json.decode(alert_type_params.error_msg)
   local vlanId = alert.vlanId or 0
   local client = ip2label(msg.client.ip, msg.vlanId)
   local server = ip2label(msg.server.ip, msg.vlanId)

   local rsp = format_utils.formatEpoch(msg.timestamp)..": " ..
      "<A HREF=\""..hostinfo2detailsurl(client) .."\">".. msg.client.ip .."</A>"..
      " <i class=\"fas fa-exchange-alt fa-lg\" aria-hidden=\"true\" data-original-title=\"\" title=\"\"></i>" ..
      "<A HREF=\""..hostinfo2detailsurl(server) .."\">".. msg.server.ip .."</A>"..
      " [CauseTX: "..msg.cause_tx.."][TypeId: "..msg.type_id.."][ASDU: ".. msg.asdu.."][Negative: "

   if(msg.negatiive == false) then
      rsp = rsp .. "True]"
   else
      rsp = rsp .. "False]"
   end
   
   -- tprint(rsp)
   
   return(rsp)
end

-- #######################################################

return alert_iec104_error
