--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"
local search_map = _GET["map_search"]
local vs_rest_utils = require "vs_rest_utils"

-- ##################################################################
-- params
local port = _GET["port"]
local sort = _GET["sort"]
local epoch = _GET["epoch_end"]
local was_down = toboolean(_GET["was_down"] or false)
local netscan_report = toboolean(_GET["netscan_report"] or false)

if (not isEmptyString(search_map)) then
    -- trim search_map string
    search_map = trimString(search_map):gsub("-",'%%-')
end
-- ##################################################################



-- ##################################################################

-- Function to retrieve data
local function retrieve_host()
    local result = vs_utils.retrieve_hosts_to_scan(epoch)

    return vs_rest_utils.format_overview_result(result, search_map, sort, port, was_down, netscan_report)
end

-- ##################################################################

-- REST response
rest_utils.answer(rest_utils.consts.success.ok, retrieve_host())
