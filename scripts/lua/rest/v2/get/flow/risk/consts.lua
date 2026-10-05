--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Read all the defined nDPI flow risks
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/flow/risk/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

-- ntop.getRiskList() stores the risk id N at index N + 1 (risk 0 is "no risk")
for index, name in pairs(ntop.getRiskList() or {}) do
   local risk_id = index - 1

   if risk_id > 0 then
      res[#res + 1] = {
         name = name,
         risk_id = risk_id,
      }
   end
end

table.sort(res, function(a, b) return a.name:lower() < b.name:lower() end)
rest_utils.answer(rc, res)
