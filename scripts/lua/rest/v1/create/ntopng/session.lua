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
-- Get a new ntopng user session (Cookie)
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"username": "mario"}' http://localhost:3000/lua/rest/v1/get/ntopng/session.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local username = _POST["username"]
local auth_session_duration = _POST["auth_session_duration"] 

if username == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

username = string.lower(username)

local duration = 0

if not isEmptyString(auth_session_duration) then
   duration = tonumber(auth_session_duration)
end

res.session = ntop.createUserSession(username, duration)

if isEmptyString(res.session) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

rest_utils.answer(rc, res)
