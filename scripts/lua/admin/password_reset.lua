--
-- (C) 2013 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local username             = _POST["username"]
local old_password         = _POST["old_password"]
local new_password         = _POST["new_password"]
local confirm_new_password = _POST["confirm_password"]

local is_admin = isAdministrator()

if(is_admin) then
   -- Only admins are allowed to change passwords for all the users, depending on the username sent in the _POST
   old_password = ""
else
   -- For non-admin users, the username written into the session is used to prevent a non-admin to change the password
   -- for any other user
   username = _SESSION["user"]
end

if((username == nil) or (old_password == nil) or (new_password == nil) or (confirm_new_password == nil)) then
   print ("{ \"result\" : -1, \"message\" : \"Invalid parameters\" }")
   return
end

username = string.lower(username)

if(new_password ~= confirm_new_password) then
   print ("{ \"result\" : -1, \"message\" : \"Password don't match\" }")
   return
end

if(ntop.resetUserPassword(_SESSION["user"], username, old_password, new_password)) then
   print ("{ \"result\" : 0, \"message\" : \"Password changed successfully\" }")
else
   print ("{ \"result\" : -1, \"message\" : \"Unable to set the new user password: perhaps the old password was invalid ?\" }")
end
