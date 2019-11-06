--
-- (C) 2019 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
--local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

local stats = ntop.getCacheStats()

for key,val in pairsByValues(stats, rev) do
   if(key ~= "num_reconnections") then
      local chart = ""

      if(ts_utils.exists("redis:hits", {ifid=getSystemInterfaceId(), command=key})) then
         chart = '<a href="?page=historical&redis_command='..key..'&ts_schema=redis:hits"><i class=\'fa fa-area-chart fa-lg\'></i></a>'
      end

      print("<tr><td>"..string.upper(string.sub(key, 5)).."</td><td class='text-center'>".. chart .."</td><td align=right>"..val.."</td></tr>\n")
   end
end

