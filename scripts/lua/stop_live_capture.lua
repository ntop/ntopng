--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

interface.select(ifname)
interface.stopLiveCapture(tonumber(_GET["capture_id"]))

sendHTTPContentTypeHeader('text/html')

print [[
   <head>
   <meta http-equiv="refresh" content="0; URL=/lua/live_capture_stats.lua" />
   </head>
]]
