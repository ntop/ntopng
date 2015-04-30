--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

username = _GET["username"]
old_password = _GET["old_password"]
new_password = _GET["new_password"]
confirm_new_password = _GET["confirm_new_password"]

user_group = ntop.getUserGroup()
if(user_group == "administrator") then
   old_password = ""
else
   -- Check to avoid that this user changes password for other users
   username = _COOKIE["user"]
end

if((username == nil) or (old_password == nil) or (new_password == nil) or (confirm_new_password == nil)) then
   print ("{ \"result\" : -1, \"message\" : \"Invalid parameters\" }")
   return
end

if(new_password ~= confirm_new_password) then
   print ("{ \"result\" : -1, \"message\" : \"Password don't match\" }")
   return
end

if(ntop.resetUserPassword(_SESSION["user"], username, old_password, new_password)) then
   print ("{ \"result\" : 0, \"message\" : \"Password changed successfully\" }")
else
   print ("{ \"result\" : -1, \"message\" : \"Unable to set the new user password: perhaps the old password was invalid ?\" }")
end
