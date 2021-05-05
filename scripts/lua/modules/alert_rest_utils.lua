--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local json = require "dkjson"
local rest_utils = require "rest_utils"
local user_scripts = require "user_scripts"
local alert_utils = require "alert_utils"
local alert_exclusions = require "alert_exclusions"

local alert_rest_utils = {}

-- #################################

-- @brief exclude an alert using the parameters that the POST has
function _exclude_flow_alert(additional_filters, delete_alerts, subdir)
   local success = false
   local script_key = _POST["script_key"]
   local alert_key = tonumber(_POST["alert_key"])
   local alert_addr = _POST["alert_addr"]

   if alert_key and alert_addr then
      success = true
   end

   if success then

      if alert_addr then
	 if alert_addr == "" then
	    -- Disable for "All", so toggle the user script to OFF
	    user_scripts.toggleScript(script_key, subdir, false --[[ turn it off --]])
	 elseif subdir == "flow" then
	    -- Disable for a specific address, need to just turn off the alert
	    alert_exclusions.disable_flow_alert(alert_addr, alert_key)
	 elseif subdir == "host" then
	    -- Disable for a specific address, need to just turn off the alert
	    alert_exclusions.disable_host_alert(alert_addr, alert_key)
	 end

	 -- Check to see if old alerts need to be deleted as well
	 if delete_alerts == "true" then
	    if subdir == "flow" then
	       alert_utils.deleteFlowAlertsMatching(alert_addr, alert_key)
	    elseif subdir == "host" then
	       alert_utils.deleteHostAlertsMatching(alert_addr, alert_key)
	    end
	 end
      end
   end

   if success then
      rc = rest_utils.consts.success.ok
      rest_utils.answer(rc)
   else
      rc = rest_utils.consts.err.invalid_args
      rest_utils.answer(rc)
   end
end

-- #################################

-- @brief exclude an alert using the parameters that the POST has
function alert_rest_utils.exclude_alert()
   -- POST parameters
   local additional_filters = _POST["filters"]
   local subdir = _POST["subdir"]
   local delete_alerts = _POST["delete_alerts"] or "false"
   
   -- Parameters used by the various functions
   local success = ""
   local new_filter  = {}
   local update_err = ""

   -- Parameters used for the rest answer
   local rc = ""
   local res = ""

   if subdir == "flow" or subdir == "host" then
      return _exclude_flow_alert(additional_filters, delete_alerts, subdir)
   end
   
   rest_utils.answer(rest_utils.consts.err.invalid_args)
end

-- #################################

return alert_rest_utils
