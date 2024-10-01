--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

--
-- Return all the actively monitored ntopng interfaces along with their ids
-- Example: curl -u admin:admin -H "Content-Type: application/json"  http://localhost:3000/lua/rest/v2/get/ntopng/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local limits = ntop.getLicenseLimits()

for limit, max in pairsByKeys(limits.max) do
    res[#res + 1] = {
        name = limit,
        values = {{
            current = limits.current[limit] or 0,
            max = max
        }}
    }
end

rest_utils.answer(rc, res)
