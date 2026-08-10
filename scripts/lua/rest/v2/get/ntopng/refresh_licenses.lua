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

local last_email = ntop.getCache("ntopng.cache.products.licenses.last_email_used") or ""
local auth_token = ntop.getHashCache("ntopng.prefs.products.licenses.auth_token", email)

if isEmptyString(last_email) or isEmptyString(auth_token) then
	rest_utils.answer(rc, {})
   return 
end

local product_licenses_url = "https://shop.ntop.org/rest/get/user/licenses.php"
local data = json.encode({ email = email, auth_token = auth_token })
local temp_fname = string.format("%s/configurations/product_licenses.txt", dirs.workingdir)
local rsp = ntop.httpPost(product_licenses_url, data, { return_content = true })

if rsp.RESPONSE_CODE == 200 then
	local response = json.decode(rsp.CONTENT)
    ntop.setCache("ntopng.cache.products.licenses.last_email_used", email)
    ntop.setCache("ntopng.cache.products.licenses.last_data", json.encode(response.licenses))
    ntop.setCache("ntopng.cache.products.licenses.last_update", os.time())
    -- Also set the last requested info/email used, in order to hasten up the process for the next calls
	rest_utils.answer(rc, response.licenses)
	return
end

rest_utils.answer(rest_utils.consts.err.internal_error)
