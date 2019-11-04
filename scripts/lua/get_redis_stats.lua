--
-- (C) 2019 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
--local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

local stats = ntop.getCacheStats()

for key,val in pairsByValues(stats, rev) do
   if(key ~= "num_reconnections") then
      print("<tr><td>"..string.upper(string.sub(key, 5)).."</td><td align=right>"..val.."</td></tr>\n")
   end
end

