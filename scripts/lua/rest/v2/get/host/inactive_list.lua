--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "mac_utils"
local rest_utils = require "rest_utils"
local inactive_hosts_utils = require "inactive_hosts_utils"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- =============================

local ifid = _GET["ifid"]
local download = _GET["download"]
local filters = {
    vlan = _GET["vlan_id"],
    network = _GET["network"],
    device_type = _GET["device_type"],
    manufacturer = _GET["manufacturer"],
}

-- Return the data
for filter, value in pairs(filters) do
    if isEmptyString(value) then
        filters[filter] = nil
    end
end

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

-- Download the data
if download == "true" then
    local format = _GET["format"]
    local rsp = ""

    if format == "csv" then
        -- CSV requested
        rsp = inactive_hosts_utils.getInactiveHosts(ifid, filters)
        rsp = inactive_hosts_utils.formatInactiveHostsCSV(rsp)
    elseif format == "json" then
        -- JSON requested
        rsp = inactive_hosts_utils.getInactiveHosts(ifid, filters)
        rsp = inactive_hosts_utils.formatInactiveHostsJSON(rsp)
    else
        -- Wrong format requested, Error!
        rest_utils.answer(rest_utils.consts.err.not_granted)
        return
    end

    rest_utils.vanilla_payload_response(rest_utils.consts.success.ok, rsp, "text/" .. format)
    return
else
    local rsp = {}
    local hosts = inactive_hosts_utils.getInactiveHosts(ifid, filters)
    
    -- Check if at least an host is inactive
    if table.len(hosts) > 0 then
        local start = _GET["start"]
        local length = _GET["length"]
        local order_field = _GET["sort"] or "last_seen"
        local order

        if (_GET["order"]) and (_GET["order"] == "asc") then
            order = asc
        else
            order = rev
        end
    
        -- Sorting the table
        table.sort(hosts, function(x, y)
            return order(x[order_field], y[order_field])
        end)
    
        -- Cutting down the table
        for key, value in pairs({table.unpack(hosts, start + 1, start + length)}) do
            rsp[key] = value
        end
        
        -- Formatting the values
        rsp = inactive_hosts_utils.formatInactiveHosts(rsp)
    end
    
    rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
        ["recordsTotal"] = #hosts
    })    
end

