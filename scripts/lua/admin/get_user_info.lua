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
	 print(' "username": "'..key..'",\n')
	 print(' "password": "'..value["password"]..'",\n')
	 print(' "full_name": "'..value["full_name"]..'",\n')
	 print(' "group": "'..value["group"]..'",\n')
	 print(' "allowed_nets": "'..value["allowed_nets"]..'"\n')
      end
   end
   
   print("}")
end