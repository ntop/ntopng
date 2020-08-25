--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local page_utils = require("page_utils")
local tracker = require("tracker")
local storage_utils = require("storage_utils")
local system_utils = require("system_utils")
local rest_utils = require("rest_utils")

--
-- Read system statistics
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/get/system/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAllowedSystemInterface() then
   rc = rest_utils.consts.err.not_granted
   rest_utils.answer(rc)
   return
end

local rc = rest_utils.consts.success.ok
local res = system_utils.systemHostStats()
res.epoch = os.time()
res.storage = storage_utils.storageInfo()

rest_utils.answer(rc, res)
