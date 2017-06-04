--
-- (C) 2013-16 - ntop.org
--

-- This lua script is basically the same as do_export_data.lua except this bypasses the csrf token to allow you to export the data without the csrf token.
-- Put this script in pfsense directory /usr/local/share/ntopng/scripts/lua/ to allow access to the data through curl.

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

-- Only needed to change ~= nil to == nil.

if(_GET["csrf"] == nil) then

interface.select(ifname)
if((_GET["hostIP"] ~= nil) and (_GET["hostIP"] ~= "")) then
   vlan = 0
   if ((_GET["hostVlan"] ~= nil) and (_GET["hostIP"] ~= "")) then
      vlan = tonumber(_GET["hostVlan"])
   end
  
   host = interface.getHostInfo(_GET["hostIP"], vlan)

   if(host == nil) then 
      print("{ }\n")
   else
      print(host["json"].."\n")
   end
else
   -- All hosts
   
   hosts_stats,total = aggregateHostsStats(interface.getHostsInfo())
   num = 0
   print("[\n")

   for key, value in pairs(hosts_stats) do
      
      host_info = split(key,"@")
      ip = host_info[1]
      vlan = host_info[2]
       
      host = interface.getHostInfo(ip,vlan)
      
      if((host ~= nil) and (host["json"] ~= nil)) then
	 if(num > 0) then print(",\n") end
	 print(host["json"])
	 num = num + 1
      end
   end

   print("\n]\n")
end
end
