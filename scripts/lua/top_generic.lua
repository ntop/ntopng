--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "top_talkers"

sendHTTPHeader('text/html; charset=iso-8859-1')

ifid = getInterfaceId(ifname)

epoch = _GET["epoch"]
module = _GET["m"]
param = _GET["param"]
mode = _GET["mode"]
add_vlan = _GET["addvlan"]

if (module == nil) then
  print("[ ]\n")
else
  if (param == nil) then param = "" end
  mod = require("top_scripts."..module)
  if (type(mod) == type(true)) then
    print("[ ]\n")
  else
     if(epoch == nil) then
	top = mod.getTopClean(ifid, ifname, mode)
     else
	epoch = epoch+60 -- we return the minute before the event as epochs are stored in the DB 'past' the time period
	top = mod.getHistoricalTop(ifid, ifname, epoch, add_vlan)
     end

     print(top)
  end
end
