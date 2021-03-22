--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local alert_keys = require "alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_suspicious_file_transfer = classes.class(alert)

-- ##############################################

alert_suspicious_file_transfer.meta = {
   alert_key = alert_keys.ntopng.alert_suspicious_file_transfer,
   i18n_title = "alerts_dashboard.suspicious_file_transfer",
   icon = "fas fa-file-download",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_suspicious_file_transfer:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_suspicious_file_transfer.format(ifid, alert, alert_type_params)
   local res = i18n("alerts_dashboard.suspicious_file_transfer")

   if alert_type_params and alert_type_params["protos.http.last_url"] then
      local type_icon = ''

      local extn = alert_type_params["protos.http.last_url"]:sub(-4):lower()

      if extn == ".php" or extn == ".js" or extn == ".html" or extn == ".xml" or extn == ".cgi" then
	 type_icon = '<i class="fas fa-file-code"></i>'
      elseif extn == ".png" or extn == ".jpg" then
	 type_icon = '<i class="fas fa-file-image"></i>'
      end

      res = i18n("alerts_dashboard.suspicious_file_transfer_url",
		 {url = shortenString(alert_type_params["protos.http.last_url"], 64),
		  type_icon = type_icon})
   end

   return res
end

-- #######################################################

return alert_suspicious_file_transfer
