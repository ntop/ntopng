--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Return all the actively monitored ntopng interfaces along with their ids
-- Example: curl -u admin:admin -H "Content-Type: application/json"  http://localhost:3000/lua/rest/v2/get/ntopng/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local email = _POST["email"]

if isEmptyString(email) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

local rc = rest_utils.consts.success.ok
local res = {}

local auth_token = ntop.getHashCache('ntopng.prefs.products.licenses.auth_token', email)
if isEmptyString(auth_token) then
    local auth_token_url = 'https://shop.ntop.org/rest/set/user/auth_token.php'
    local data = json.encode({ email = email })
    local rsp = ntop.httpPost(auth_token_url, data)

    if rsp.RESPONSE_CODE == 200 then
        rest_utils.answer(rc)
        return
    else
        rest_utils.answer(rest_utils.consts.err.internal_error)
        return
    end
end

rest_utils.answer(rc, auth_token)