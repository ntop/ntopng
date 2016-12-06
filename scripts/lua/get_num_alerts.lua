--
-- (C) 2016 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

interface.select(ifname)

sendHTTPHeader('text/html; charset=iso-8859-1')

if(_GET["status"] ~= nil) then
   local res = performAlertsQuery("SELECT COUNT(*) AS count", _GET["status"], UrlToalertsQueryParameters(_GET))

   if((res ~= nil) and (#res == 1) and (res[1].count ~= nil)) then
      print(res[1].count)
   end

   return
end
