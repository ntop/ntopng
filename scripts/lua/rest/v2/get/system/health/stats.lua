--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local storage_utils = require("storage_utils")
local cpu_utils = require("cpu_utils")
local rest_utils = require("rest_utils")

--
-- Read system statistics
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/system/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAllowedSystemInterface() then
   rc = rest_utils.consts.err.not_granted
   rest_utils.answer(rc)
   return
end

local rc = rest_utils.consts.success.ok
local res = cpu_utils.systemHostStats()
res.epoch = os.time()
res.storage = storage_utils.storageInfo()

local info = ntop.getInfo()
if(info.pid ~= nil) then
   res.pid = info.pid
end

rest_utils.answer(rc, res)
