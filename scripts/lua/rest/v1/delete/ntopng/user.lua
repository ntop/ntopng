--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")

--
-- Remove a ntopng user
-- Example: curl -u admin:admin -d '{"username": "mario"}' http://localhost:3000/lua/rest/v1/delete/ntopng/user.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

if not haveAdminPrivileges() then
   print(rest_utils.rc(rest_utils.consts_not_granted, res))
   return
end

local username = _POST["username"]

if username == nil then
   print(rest_utils.rc(rest_utils.consts_invalid_args, res))
   return
end

username = string.lower(username)

if not ntop.deleteUser(username) then
   print(rest_utils.rc(rest_utils.consts_delete_user_failed, res))
   return
end

print(rest_utils.rc(rc, res))

