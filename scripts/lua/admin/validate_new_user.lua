--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(isAdministratorOrPrintErr()) then
   local json = require "dkjson"
   local username = string.lower(_GET["username"] or "")
   local existing = ntop.getCache("ntopng.user.".. username ..".password")

   -- Same answer as before, encoded (the username is user input)
   if(string.len(existing) > 0) then
      print(json.encode({ valid = 0, user = username, msg = "User already existing" }) .. "\n")
   else
      print(json.encode({ valid = 1, user = username, msg = "Ok" }) .. "\n")
   end
end
