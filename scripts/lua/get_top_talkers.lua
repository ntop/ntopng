--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "top_talkers"

sendHTTPContentTypeHeader('text/html')

tracked_host = _GET["host"]

ifid = getInterfaceId(ifname)
epoch = _GET["epoch"]
mod = require("top_scripts.top_talkers")
if (type(mod) == type(true)) then
  print("[ ]\n")
else
   top_talkers = mod.getTop(ifid, ifname, epoch)
   print(top_talkers)
end
