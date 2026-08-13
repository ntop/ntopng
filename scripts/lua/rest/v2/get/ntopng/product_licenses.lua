--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
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

local rc = rest_utils.consts.success.ok

local email = _POST["email"]
local auth_token = _POST["auth_token"]

if isEmptyString(email) or isEmptyString(auth_token) then
    -- Basic REST API, requesting for last retrieved data
    local data = ntop.getCache("ntopng.cache.products.licenses.last_data") or "{}"
	rest_utils.answer(rc, json.decode(data))
	return
end

local product_licenses_url = "https://shop.ntop.org/rest/get/user/licenses.php"
local data = json.encode({ email = email, auth_token = auth_token })
local rsp = ntop.httpPost(product_licenses_url, data, { return_content = true })
if rsp and rsp.RESPONSE_CODE == 200 then
	local response = json.decode(rsp.CONTENT)

	if response and response.licenses then
		-- Store the credentials in the cache only once they are known to be
		-- valid: refresh_licenses.lua reuses them to update the licenses
		-- without asking the user again
		ntop.setHashCache("ntopng.prefs.products.licenses.auth_token", email, auth_token)
		ntop.setCache("ntopng.cache.products.licenses.last_email_used", email)
		ntop.setCache("ntopng.cache.products.licenses.last_data", json.encode(response.licenses))
		ntop.setCache("ntopng.cache.products.licenses.last_update", os.time())

		rest_utils.answer(rc, response.licenses)
		return
	end
end

rest_utils.answer(rest_utils.consts.err.internal_error)