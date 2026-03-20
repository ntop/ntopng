--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Get top hosts by ICMP traffic
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/interface/icmp_hosts.lua?ifid=1&version=4
--

local rc  = rest_utils.consts.success.ok
local res = {}

-- #####################################################################

local ifid       = _GET["ifid"]
local ip_version = _GET["version"] or "4"

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

-- #####################################################################

local icmp_key = (ip_version == "6") and "ICMPv6" or "ICMPv4"

-- #####################################################################

local hosts_stats = interface.getHostsInfo(false, "column_traffic")
hosts_stats = hosts_stats["hosts"]

-- Build a list sorted by total ICMP packets descending.
-- Using an array of {packets, host_key} to avoid key-collision issues
-- that arise when using packets as a table key.
local sortable = {}

for host_key, host_value in pairs(hosts_stats) do
    local icmp_table = host_value[icmp_key]
    if icmp_table ~= nil then
        local host_packets = 0

        for _, type_code_value in pairs(icmp_table) do
            host_packets = host_packets
                + (type_code_value.sent or 0)
                + (type_code_value.rcvd or 0)
        end

        if host_packets > 0 then
            sortable[#sortable + 1] = { packets = host_packets, host_key = host_key }
        end
    end
end

-- Sort descending by packets
table.sort(sortable, function(a, b) return a.packets > b.packets end)

-- #####################################################################

local max_num_entries = 10

for i = 1, math.min(table.len(sortable), max_num_entries) do
    local entry     = sortable[i]
    local host_key  = entry.host_key
    local host_info = hosts_stats[host_key]

    res[#res + 1] = {
        host = {
            label = hostinfo2label(host_info, true, false, true),
            url   = ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url(host_key),
        },
        packets = entry.packets,
    }
end

rest_utils.answer(rc, res)