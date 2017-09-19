--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

interface.select(ifname)

if(haveAdminPrivileges() and (_POST["l7proto"] ~= nil)) then
   local app_id     = tonumber(_POST["l7proto"])
   local new_cat_id = tonumber(_POST["ndpi_new_cat_id"])
   local old_cat_id = tonumber(_POST["ndpi_old_cat_id"])

   if new_cat_id ~= nil and old_cat_id ~= nil and new_cat_id ~= old_cat_id then
      setCustomnDPIProtoCategory(ifname, app_id, new_cat_id)
   end

   local res = {status = "OK", new_csrf = ntop.getRandomCSRFValue()}
   print(json.encode(res))
else
   print({status = "ERROR"})
end
