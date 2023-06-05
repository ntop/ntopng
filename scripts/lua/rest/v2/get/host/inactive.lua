--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local inactive_hosts = require "inactive_hosts"
local discover_utils = require "discover_utils"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- =============================

local ifid = _GET["ifid"]

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

local rsp = {}
local hosts = inactive_hosts.getOfflineHosts(ifid)

if table.len(hosts) > 0 then
    local format_utils = require("format_utils")
    local start = _GET["start"]
    local length = _GET["length"]
    local order_field = _GET["sort"] or "last_seen"
    local order

    if (_GET["order"]) and (_GET["order"] == "asc") then
        order = asc
    else
        order = rev
    end

    table.sort(hosts, function(x, y)
        return order(x[order_field], y[order_field])
    end)

    -- Cutting down the table
    for key, value in pairs({table.unpack(hosts, start + 1, start + length)}) do
        rsp[key] = value
    end

    for key, value in pairs(rsp) do
        rsp[key]["last_seen"] = format_utils.formatPastEpochShort(value["last_seen"])
        rsp[key]["first_seen"] = format_utils.formatPastEpochShort(value["first_seen"])
        rsp[key]["device_type"] = discover_utils.devtype2icon(value["device_id"]) .. " " .. value["device_type"]
    end
end

rest_utils.extended_answer(rest_utils.consts.success.ok, rsp, {
    ["recordsTotal"] = #hosts
})
