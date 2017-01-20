--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(haveAdminPrivileges()) then
   print("{\n")
   
   users_list = ntop.getUsers()
   for key, value in pairs(users_list) do
      if(key == _GET["user"]) then

	 if value["group"] == "captive_portal" then
	    print(' "host_pool_id": "'..value["host_pool_id"]..'",\n')
	    if value["limited_lifetime"] then
	       print(' "limited_lifetime": true,\n')
	    end
	 else
	    print(' "allowed_nets": "'..value["allowed_nets"]..'",\n')
	    print(' "allowed_ifname": "'..value["allowed_ifname"]..'",\n')
	 end

	 print(' "username": "'..key..'",\n')
	 print(' "password": "'..value["password"]..'",\n')
	 print(' "full_name": "'..value["full_name"]..'",\n')
	 print(' "group": "'..value["group"]..'"\n')

      end
   end
   
   print("}")
end
