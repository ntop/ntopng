--
-- (C) 2019-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local script_manager = require("script_manager")
local rest_utils = require("rest_utils")

-- ################################################

local cmd_ids_filter = _GET["custom_hosts"]

-- ################################################

if (cmd_ids_filter) then
    cmd_ids_filter = swapKeysValues(string.split(cmd_ids_filter, ",") or
                                        {cmd_ids_filter})
end

local commands_stats = ntop.getCacheStats() or {}
local res = {}
local charts_available = script_manager.systemTimeseriesEnabled()
for command, hits in pairs(commands_stats) do
    res[#res + 1] = {
        command = {
            key = command,
            name = string.upper(string.sub(command, 5)),
        },
        hits = formatValue(hits)
    }
end

-- ################################################

rest_utils.extended_answer(rest_utils.consts.success.ok, res,
                           {["recordsTotal"] = #res})
