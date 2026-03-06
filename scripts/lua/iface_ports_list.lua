--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require "format_utils"
local rest_utils   = require "rest_utils"

local host_info = url2hostinfo(_GET)
local host_key  = hostinfo2hostkey(host_info)

if isEmptyString(host_key) then
    host_info = nil
    host_key  = nil
end

local function fill_ports_array(field_key, flows_stats)
    local ports_array = {}
    for _, value in ipairs(flows_stats) do
        local p = value[field_key .. ".port"]
        if p ~= nil then
            ports_array[p] = (ports_array[p] or 0) + value["bytes"]
        end
    end
    return ports_array
end

local flows_stats = interface.getFlowsInfo(host_key) or {}
if flows_stats["flows"] then
    flows_stats = flows_stats["flows"]
end

local client_ports = fill_ports_array("cli", flows_stats)
local server_ports = fill_ports_array("srv", flows_stats)
local ports = (_GET["clisrv"] == "server") and server_ports or client_ports

local tot = 0
for _, v in pairs(ports) do
    tot = tot + v
end

local threshold_percent = 5
local threshold         = (tot * threshold_percent) / 100

local res       = {}
local num       = 0
local accumulate = 0

for key, value in pairsByValues(ports, rev) do
    if value < threshold then break end

    local url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua?port=" .. key
    if host_key then
        url = url .. "&host=" .. host_key
    end

    res[#res + 1] = {
        label = tostring(key),
        value = value,
        url   = url,
    }

    accumulate = accumulate + value
    num        = num + 1
end

-- Leftover "Other" slice
if accumulate < tot then
    local other_label = i18n("other")
    local url         = hostinfo2detailsurl(host_info, { page = "flows" })

    if num == 0 and table.len(ports) > 0 then
        other_label = i18n("num_different_ports", {
            num       = format_utils.formatValue(table.len(ports)),
            threshold = threshold_percent,
        })
    end

    res[#res + 1] = {
        label = other_label,
        value = tot - accumulate,
        url   = url,
    }
end

if tot == 0 then
    res[#res + 1] = { label = i18n("no_ports"), value = 0 }
end

rest_utils.answer(rest_utils.consts.success.ok, res)