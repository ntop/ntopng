--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

interface.select(ifname)

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

if(_GET["csrf"] ~= nil) then
   if(_GET["id_to_delete"] ~= nil) then
      if(_GET["id_to_delete"] == "__all__") then
	 interface.deleteAlerts(true --[[ engaged --]])
	 interface.deleteAlerts(false --[[ and not engaged --]])
	 print("")
      else
	 local id_to_delete = tonumber(_GET["id_to_delete"])
	 if id_to_delete ~= nil then
	    if _GET["engaged"] == "true" then
	       interface.deleteAlerts(true, id_to_delete)
	    else
	       interface.deleteAlerts(false, id_to_delete)
	    end
	 end
      end
   end
end

active_page = "alerts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local num_alerts         = interface.getNumAlerts(false --[[ NOT engaged --]])
local num_engaged_alerts = interface.getNumAlerts(true --[[ engaged --]])
if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Alerts are disabled. Please check the preferences page to enable them.</div>")
--return
elseif num_alerts == 0 and num_engaged_alerts == 0 then
   print("<div class=\"alert alert alert-info\"><img src=".. ntop.getHttpPrefix() .. "/img/info_icon.png> No recorded alerts so far for interface "..ifname.."</div>")
else

   drawAlertTables(num_alerts, num_engaged_alerts)

end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
