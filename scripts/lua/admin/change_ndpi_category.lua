--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

interface.select(ifname)

if(haveAdminPrivileges()) then
   local app_id     = tonumber(_GET["l7proto"])
   local new_cat_id = tonumber(_GET["ndpi_new_cat_id"])
   local old_cat_id = tonumber(_GET["ndpi_old_cat_id"])

   if new_cat_id ~= nil and old_cat_id ~= nil and new_cat_id ~= old_cat_id then
      setCustomnDPIProtoCategory(ifname, app_id, new_cat_id)
   end

   local res = {status = "OK"}
   print(json.encode(res))
else
   print({status = "ERROR"})
end
