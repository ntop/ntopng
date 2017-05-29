--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(haveAdminPrivileges()) then
   key = "ntopng.user.".. string.lower(_GET["username"]) ..".password"
   existing = ntop.getCache(key)
   
   if(string.len(existing) > 0) then
      print('{ "valid" : 0, "user": "'.. string.lower(_GET["username"])..'", "msg": "User already existing" }\n')
      return
   else
      valid = 1
   end

   print('{ "valid" : 1, "user": "'.. string.lower(_GET["username"])..'", "msg": "Ok" }\n')
end
