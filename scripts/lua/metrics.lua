--
-- (C) 2017-19 - ntop.org
--
-- Prometheus integration script
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/plain')

local prometheus_queue = "ntopng.prometheus_export_queue"

while(true) do
   local line = ntop.rpopCache(prometheus_queue)

   if(line == nil) then
      break
   else
      print(line.."\n")
   end
end
