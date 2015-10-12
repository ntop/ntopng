--
-- (C) 2013-15 - ntop.org
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
   else
      -- check if alerts count must be flushed or decremented
      if(host["num_alerts"] > 0) then
      	 if(ntop.getNumQueuedAlerts() == 0) then
      	    host["num_alerts"] = 0;
      	 else
      	    host["num_alerts"] = ntop.getNumQueuedAlerts();
      	 end
      end
   end
else
   host = "{}"
end


sendHTTPHeader('text/html; charset=iso-8859-1')
--sendHTTPHeader('application/json')

print(json.encode(host, { indent = true }))
