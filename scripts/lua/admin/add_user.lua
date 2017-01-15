--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

if(haveAdminPrivileges()) then
   username = _POST["username"]
   full_name = _POST["full_name"]
   password = _POST["password"]
   confirm_password = _POST["confirm_password"]
   host_role = _POST["host_role"]
   networks = _POST["allowed_networks"]
   allowed_interface = _POST["allowed_interface"]
   
   if(username == nil or full_name == nil or password == nil or confirm_password == nil or host_role == nil or networks == nil or allowed_interface == nil) then
      print ("{ \"result\" : -1, \"message\" : \"Invalid parameters\" }")
      return
   end
   
   if(password ~= confirm_password) then
      print ("{ \"result\" : -1, \"message\" : \"Passwords do not match: typo?\" }")
      return
   end
   
   if(ntop.addUser(username, full_name, password, host_role, networks, getInterfaceName(allowed_interface))) then
      print ("{ \"result\" : 0, \"message\" : \"User added successfully\" }")
   else
      print ("{ \"result\" : -1, \"message\" : \"Error while adding new user\" }")
   end
end
