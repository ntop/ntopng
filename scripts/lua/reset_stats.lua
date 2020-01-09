--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

local action = _POST["resetstats_mode"]
local ifid = _POST["ifid"]

interface.select(ifid)

local res = { ["status"] = "ok" }
if((action ~= nil) and (haveAdminPrivileges())) then
   if action == "reset_drops" then
      interface.resetCounters(true --[[ reset only drops --]])
   elseif action == "reset_all" then
      interface.resetCounters(false --[[ reset all counters --]])
   end
else
   res["status"] = "unauthorized"
end

print(json.encode(res, nil))
