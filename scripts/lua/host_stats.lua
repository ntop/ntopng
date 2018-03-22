--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

local json = require ("dkjson")

host_info = url2hostinfo(_GET)

if((host_info ~= nil) and (host_info["host"] ~= nil)) then
   interface.select(ifname)
   host = interface.getHostInfo(host_info["host"], host_info["vlan"]) 
   if(host == nil) then
      host = "{}"
   end
else
   host = "{}"
end


sendHTTPContentTypeHeader('text/html')
--sendHTTPHeader('application/json')

print(json.encode(host, { indent = true }))
