--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")

--
-- Get all available users
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v1/get/ntopng/users.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

if not isAdministratorOrPrintErr() then
   local res = {}
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

local all_users = ntop.getUsers()

rest_utils.answer(rc, all_users)
