--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")
local tracker = require("tracker")

--
-- Remove a ntopng user
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"username": "mario"}' http://localhost:3000/lua/rest/v1/delete/ntopng/user.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

local username = _POST["username"]

if username == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args, res)
   return
end

username = string.lower(username)

if not ntop.deleteUser(username) then
   rest_utils.answer(rest_utils.consts.err.delete_user_failed, res)
   return
end

rest_utils.answer(rc, res)

-- TRACKER HOOK
-- Note: already tracked by ntop.deleteUser
-- tracker.log('delete_ntopng_user', { username = username })
