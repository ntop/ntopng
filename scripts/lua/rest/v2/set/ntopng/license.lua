--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Sets the ntopng license key.
-- Example: curl -u admin:admin -H "Content-Type: application/json" \
--   -d '{"ntopng_license": "<key>"}' \
--   http://localhost:3000/lua/rest/v2/set/ntopng/license.lua
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local license_key = _POST["ntopng_license"]

if isEmptyString(license_key) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

ntop.setCache("ntopng.license", trimSpace(license_key))
ntop.checkLicense()

rest_utils.answer(rest_utils.consts.success.ok, {})
