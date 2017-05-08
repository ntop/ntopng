--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

if _GET["ifid"] ~= nil then
   interface.select(_GET["ifid"])
end

if((_GET["ip"] ~= nil) and (_GET["ip"] ~= "")) then
   vlan = 0
   if ((_GET["vlan"] ~= nil) and (_GET["vlan"] ~= "")) then
      vlan = tonumber(_GET["vlan"])
   end
  
   host = interface.getHostInfo(_GET["ip"], vlan)

   if(host == nil) then 
      print("{ }\n")
   else
      print(host["json"].."\n")
   end
else
   -- All hosts
   
   hosts_stats = interface.getHostsInfo()
   hosts_stats = hosts_stats["hosts"]
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
