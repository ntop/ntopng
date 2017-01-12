--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

if(_GET["csrf"] ~= nil) then
if(haveAdminPrivileges()) then
   username = _GET["username"]
   full_name = _GET["full_name"]
   password = _GET["password"]
   confirm_password = _GET["confirm_password"]
   host_role = _GET["host_role"]
   networks = _GET["allowed_networks"]
   allowed_interface = _GET["allowed_interface"]
   
   if(username == nil or full_name == nil or password == nil or confirm_password == nil or host_role == nil or networks == nil or allowed_interface == nil) then
      print ("{ \"result\" : -1, \"message\" : \"Invalid parameters\" }")
      return
   end
   
   if(password ~= confirm_password) then
      print ("{ \"result\" : -1, \"message\" : \"Passwords do not match: typo?\" }")
      return
   end
   
   if(ntop.addUser(username, full_name, password, host_role, networks, allowed_interface)) then
      print ("{ \"result\" : 0, \"message\" : \"User added successfully\" }")
   else
      print ("{ \"result\" : -1, \"message\" : \"Error while adding new user\" }")
   end
end
end