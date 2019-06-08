--
-- (C) 2016-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

if _GET["ifid"] ~= nil then
   interface.select(_GET["ifid"])
end

sendHTTPContentTypeHeader('text/html')

if(_GET["status"] ~= nil) then
   local num = getNumAlerts(_GET["status"], _GET)
   print(tostring(num))
end
