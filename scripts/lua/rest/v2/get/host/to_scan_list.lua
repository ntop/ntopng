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

local function format_result(result) 
    local rsp = {}
    if result then
        for _,value in ipairs(result) do
            if (isEmptyString(search_map)) then
                rsp[#rsp+1] = value
                rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
            else 
                if (value.host == search_map or string.find(value.host,search_map)) then
                    rsp[#rsp+1] = value
                    rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                    rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                end
            end
        end
    end
    return rsp 
end

local function retrieve_host(host) 
    local result = vs_utils.retrieve_hosts_to_scan()

    return format_result(result)
end

rest_utils.answer(rest_utils.consts.success.ok, retrieve_host())

