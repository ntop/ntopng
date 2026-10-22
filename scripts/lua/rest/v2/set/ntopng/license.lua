--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Parses the JSON POST payload and validates/sanitizes _GET/_POST (normally
-- loaded by lua_utils): must be required before reading the parameters
require "http_lint"
require "ntop_utils" -- isAdministrator(), isEmptyString()
require "string_utils" -- trimSpace()
local rest_utils = require "rest_utils"

--
-- Sets the ntopng license key.
-- Example: curl -u admin:admin -H "Content-Type: application/json" \
--   -d '{"ntopng_license": "<key>"}' \
--   http://localhost:3000/lua/rest/v2/set/ntopng/license.lua
--

-- NOTE: isAdministratorOrPrintErr() would print an HTML error before the JSON answer
if not isAdministrator() then
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
