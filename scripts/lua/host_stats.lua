--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

local json = require ("dkjson")

local host_info = url2hostinfo(_GET)

if((host_info ~= nil) and (host_info["host"] ~= nil)) then
   interface.select(ifname)
   host = interface.getHostInfo(host_info["host"], host_info["vlan"])
   if(host == nil) then
      host = "{}"
   else
      local hostinfo = {host=host["ip"], vlan=host["vlan"]}

      host["name"] = hostinfo2label(host)

      if((host["ip"] == host["name"]) and ntop.shouldResolveHost(host["ip"])) then
         -- Actively resolve host if resolution is enabled
         host["name"] = resolveAddress(hostinfo)
      end
   end
else
   host = "{}"
end


sendHTTPContentTypeHeader('text/html')
--sendHTTPHeader('application/json')

print(json.encode(host, { indent = true }))
