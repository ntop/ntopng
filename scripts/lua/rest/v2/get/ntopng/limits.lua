--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Parses the JSON POST payload and validates/sanitizes _GET/_POST (normally
-- loaded by lua_utils): must be required before reading the parameters
require "http_lint"
require "ntop_utils" -- pairsByKeys(), isAdministrator()
local rest_utils = require("rest_utils")

--
-- Return limits for the current ntopng license
-- Example: curl -u admin:admin -H "Content-Type: application/json"  http://localhost:3000/lua/rest/v2/get/ntopng/limits.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

-- Same permissions of the page (Help -> License -> Limits)
if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local rc = rest_utils.consts.success.ok
local res = {}

local limits = ntop.getLicenseLimits()

for limit, max in pairsByKeys(limits.max) do
    res[#res + 1] = {
        limit = limit,
        current = limits.current[limit] or 0,
        max = max
    }
end

rest_utils.answer(rc, res)
