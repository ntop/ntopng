--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local storage_utils = require("storage_utils")
local cpu_utils = require("cpu_utils")
local rest_utils = require("rest_utils")

--
-- Read system statistics
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v1/get/system/stats.lua
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

rest_utils.answer(rc, res)
