--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

if(haveAdminPrivileges()) then
   username = _GET["username"]
   
   if(username == nil) then
      print ("{ \"result\" : -1, \"message\" : \"Invalid parameters\" }")
      return
   end
   
   if(ntop.deleteUser(username)) then
      print ("{ \"result\" : 0, \"message\" : \"User deleted successfully\" }")
   else
      print ("{ \"result\" : -1, \"message\" : \"Error deleting user\" }")
   end
end
