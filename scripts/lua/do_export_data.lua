--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

if(_POST["export"] ~= nil) then

interface.select(ifname)
if((_POST["ip"] ~= nil) and (_POST["ip"] ~= "")) then
   vlan = 0
   if ((_POST["vlan"] ~= nil) and (_POST["vlan"] ~= "")) then
      vlan = tonumber(_POST["vlan"])
   end
  
   host = interface.getHostInfo(_POST["ip"], vlan)

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
end
