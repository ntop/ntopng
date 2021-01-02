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
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"username": "simone"}' http://localhost:3000/lua/rest/v1/create/ntopng/api_token.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

-- An admin user can submit a username to create token for other users
-- A non-admin user can only create tokens for itself
local username = _POST["username"]

-- Do not allow non-admins to specify usernames different from their username
if not isAdministrator() and _POST["username"] and _POST["username"] ~= _SESSION['user'] then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- Take the username specified in the post or the name of the currently authenticated user
-- if no username has been submitted
local username = _POST["username"] or _SESSION['user']
username = string.lower(username)

res.api_token = ntop.createUserAPIToken(username)

if isEmptyString(res.api_token) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

rest_utils.answer(rc, res)
