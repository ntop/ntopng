--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(haveAdminPrivileges()) then
   print("{\n")
   
   local users_list = ntop.getUsers()
   for key, value in pairs(users_list) do
      if(key == _GET["username"]) then

	 if value["group"] == "captive_portal" then
	    print(' "host_pool_id": "'..value["host_pool_id"]..'",\n')
	    if value["limited_lifetime"] then
	       print(' "limited_lifetime": '..value["limited_lifetime"]..',\n')
	    end
	 else
	    print(' "allowed_nets": "'..value["allowed_nets"]..'",\n')
	    print(' "allowed_ifname": "'..value["allowed_ifname"]..'",\n')

	    if(value["allowed_ifname"] ~= "") then
	       local iface_id = interface.name2id(value["allowed_ifname"])
               print(' "allowed_if_id": "'..iface_id..'",\n')
	    end
	 end

	 print(' "username": "'..key..'",\n')
	 print(' "password": "'..value["password"]..'",\n')
	 print(' "full_name": "'..value["full_name"]..'",\n')
	 print(' "group": "'..value["group"]..'"\n')

      end
   end
   
   print("}")
end
