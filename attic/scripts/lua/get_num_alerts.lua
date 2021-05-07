--
-- (C) 2016-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"

if not isEmptyString(_GET["ifid"]) then
   interface.select(_GET["ifid"])
end

sendHTTPContentTypeHeader('text/html')

if(_GET["status"] ~= nil) then
   local num = alert_utils.getNumAlerts(_GET["status"], _GET)
   print(tostring(num))
end
