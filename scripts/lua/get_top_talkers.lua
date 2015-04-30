--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "top_talkers"

sendHTTPHeader('text/html; charset=iso-8859-1')

tracked_host = _GET["host"]

ifid = getInterfaceId(ifname)
epoch = _GET["epoch"]
mod = require("top_scripts.top_talkers")
if (type(mod) == type(true)) then
  print("[ ]\n")
else
  if (epoch ~= nil) then
    top_talkers = mod.getHistoricalTop(ifid, ifname, epoch)
  else
    top_talkers = mod.getTop(ifid, ifname, epoch)
  end
  print(top_talkers)
end
