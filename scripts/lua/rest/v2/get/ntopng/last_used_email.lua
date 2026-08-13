--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Return the email used for the last licenses import, along with the time of
-- the import itself
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/ntopng/last_used_email.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
	rest_utils.answer(rest_utils.consts.err.not_granted)
	return
end

local rc = rest_utils.consts.success.ok

-- Basic REST API, requesting for last retrieved data
local last_email = ntop.getCache("ntopng.cache.products.licenses.last_email_used") or ""
local last_update = tonumber(ntop.getCache("ntopng.cache.products.licenses.last_update"))

rest_utils.answer(rc, { last_email = last_email, last_update = last_update })
return
