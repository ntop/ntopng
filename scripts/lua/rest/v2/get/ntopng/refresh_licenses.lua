--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Refresh the product licenses reusing the credentials (email + auth token)
-- already stored in the cache by product_licenses.lua, so that the user does
-- not have to type them again.
--
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/ntopng/refresh_licenses.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
	rest_utils.answer(rest_utils.consts.err.not_granted)
	return
end

local rc = rest_utils.consts.success.ok

local email = ntop.getCache("ntopng.cache.products.licenses.last_email_used")

if isEmptyString(email) then
	-- Licenses have never been imported: there is nothing to refresh,
	-- the caller has to ask the user for the email first
	rest_utils.answer(rest_utils.consts.err.invalid_args)
	return
end

local auth_token = ntop.getHashCache("ntopng.prefs.products.licenses.auth_token", email)

if isEmptyString(auth_token) then
	rest_utils.answer(rest_utils.consts.err.invalid_args)
	return
end

local product_licenses_url = "https://shop.ntop.org/rest/get/user/licenses.php"
local data = json.encode({ email = email, auth_token = auth_token })
local rsp = ntop.httpPost(product_licenses_url, data, { return_content = true })

if rsp and rsp.RESPONSE_CODE == 200 then
	local response = json.decode(rsp.CONTENT)

	if response and response.licenses then
		local now = os.time()

		-- Keep the cache in sync, exactly as product_licenses.lua does
		ntop.setCache("ntopng.cache.products.licenses.last_email_used", email)
		ntop.setCache("ntopng.cache.products.licenses.last_data", json.encode(response.licenses))
		ntop.setCache("ntopng.cache.products.licenses.last_update", now)

		-- Return the new timestamp as well, so that the caller can update the
		-- "Last update" label without a second request
		rest_utils.answer(rc, {
			licenses = response.licenses,
			last_email = email,
			last_update = now,
		})
		return
	end
end

rest_utils.answer(rest_utils.consts.err.internal_error)	