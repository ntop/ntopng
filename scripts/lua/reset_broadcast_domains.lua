--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

local ifid = _POST["ifid"]
local res = { ["status"] = "ok" }


-- ##################################

local function reset_broadcast_domains(ifids)
   interface.select(ifids)
      
   if isAdministrator() then
	   interface.resetBroadcastDomains()
   else
      res["status"] = "unauthorized to reset broadcast domains: " .. ifids
   end
end

-- ##################################

reset_broadcast_domains(ifid)
print(json.encode(res, nil))
