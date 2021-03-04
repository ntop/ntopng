--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

local action = _POST["resetstats_mode"]
local ifid = _POST["ifid"]
local res = { ["status"] = "ok" }


-- ##################################

-- Function used to reset the stats
local function reset_stats(ifids)
   interface.select(ifids)
      
   if isAdministrator() then
      if action == "reset_drops" then
	 interface.resetCounters(true --[[ reset only drops --]])
      elseif action == "reset_all" then
	 interface.resetCounters(false --[[ reset all counters --]])
      end
   else
      res["status"] = "unauthorized to reset interface: " .. ifids
   end
end

-- ##################################

if action ~= nil then
   -- Reset counters for all interfaces
   if not ifid then
      local ifs = interface.getIfNames()

      for ifids, name in pairs(ifs) do
	 if ifids == -1 then
	    goto continue
	 end

	 reset_stats(ifids)
	 ::continue::
      end
   else
      -- Reset counters for a specific interface
      reset_stats(ifid)
   end
end

print(json.encode(res, nil))
