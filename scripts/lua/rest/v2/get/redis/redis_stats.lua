--
-- (C) 2019-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

-- ################################################

-- -1: the system interface (Health > Redis)
if not ntop.isAllowedInterface(-1) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local commands_stats = ntop.getCacheStats() or {}
local res = {}

for command, hits in pairs(commands_stats) do
    res[#res + 1] = {
        command = {
            key = command,
            -- "num_hget" -> "HGET"
            name = string.upper(string.sub(command, 5)),
        },
        hits = hits
    }
end

-- ################################################

rest_utils.extended_answer(rest_utils.consts.success.ok, res,
                           {["recordsTotal"] = #res})
