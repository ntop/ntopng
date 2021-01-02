--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local json = require("dkjson")
require "lua_utils"

if _POST and isAdministrator() then
   local dismiss_missing_geoip_reminder = _POST["dismiss_missing_geoip_reminder"]

   if not isEmptyString(dismiss_missing_geoip_reminder) then
      if dismiss_missing_geoip_reminder == "true" then
	      ntop.setPref("ntopng.prefs.geoip.reminder_dismissed", "true")
      end
   end
end

sendHTTPContentTypeHeader('application/json')

print(json.encode({status = "OK"}))
