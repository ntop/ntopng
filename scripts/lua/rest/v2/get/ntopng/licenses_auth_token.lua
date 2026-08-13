--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Return the Authentication Token associated to an e-mail address.
-- When the token is not known (or the caller asks for a new one with
-- force_new) the ntop shop is asked to send it to the e-mail address.
--
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"email":"user@example.com"}' http://localhost:3000/lua/rest/v2/get/ntopng/licenses_auth_token.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- Minimum delay, in seconds, between two token requests for the same address
local AUTH_TOKEN_MIN_INTERVAL = 60

local email = _POST["email"]
-- Ask the shop for a new token even if one is already cached: needed when the
-- cached token is no longer accepted, otherwise the user has no way to get a
-- new e-mail
local force_new = toboolean(_POST["force_new"])

if isEmptyString(email) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

local rc = rest_utils.consts.success.ok
local auth_token_key = 'ntopng.prefs.products.licenses.auth_token'
local auth_token = ntop.getHashCache(auth_token_key, email)

if not isEmptyString(auth_token) and not force_new then
    -- Token already known: no e-mail is sent, the caller can use it right away
    rest_utils.answer(rc, auth_token)
    return
end

-- One request per minute for the whole instance
local rate_limit_key = 'ntopng.cache.products.licenses.auth_token_request'
local last_request = tonumber(ntop.getCache(rate_limit_key))

if last_request then
    local retry_after = AUTH_TOKEN_MIN_INTERVAL - (os.time() - last_request)

    if retry_after > 0 then
        -- Answered as a success on purpose: the caller only needs to know how
        -- long is left, and an error status would reach it as a bare failure
        rest_utils.answer(rc, { rate_limited = true, retry_after = retry_after })
        return
    end
end

if force_new then
    -- Drop the stale token, it would otherwise shadow the one being sent
    ntop.delHashCache(auth_token_key, email)
end

-- Take the slot before the call: the point is to cap the outbound rate, so a
-- failing shop must not turn into a retry loop
ntop.setCache(rate_limit_key, os.time(), AUTH_TOKEN_MIN_INTERVAL)

local auth_token_url = 'https://shop.ntop.org/rest/set/user/auth_token.php'
local data = json.encode({ email = email })
local rsp = ntop.httpPost(auth_token_url, data)

if rsp and rsp.RESPONSE_CODE == 200 then
    -- The token is on its way to the mailbox, nothing to return here
    rest_utils.answer(rc)
    return
end

rest_utils.answer(rest_utils.consts.err.internal_error)