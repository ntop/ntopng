--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local icmp_utils = require "icmp_utils"

-- #####################################################################

local rc = rest_utils.consts.success.ok
local res = {}

-- ?ifid= (the interface pages), else the interface of the session
local ifid = _GET["ifid"]
if isEmptyString(ifid) then
   interface.select(ifname)
else
   interface.select(ifid)
   -- interface.select() silently keeps the interface of the user when this one is not allowed
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

local host_info = url2hostinfo(_GET)
local ip_version = _GET["version"] or "4"

-- #####################################################################

local is_host
local stats

if host_info["host"] ~= nil then
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
   is_host = true
else
   stats = interface.getStats()
   is_host = false
end

-- #####################################################################

if stats ~= nil then
    local icmp_key

    if ip_version == "6" then
        icmp_key = "ICMPv6"
    else
        icmp_key = "ICMPv4"
    end

    local is_v4 = (icmp_key == "ICMPv4")
    local icmp = stats[icmp_key]

    if icmp ~= nil then
        for key, value in pairsByKeys(icmp) do
            local keys = string.split(key, ",")
            local icmp_type  = keys[1]
            local icmp_value = keys[2]

            local packets = (value.sent or 0) + (value.rcvd or 0)

            local entry = {
                icmp_message = {
                    label = icmp_utils.get_icmp_label(icmp_type, icmp_value, ternary(is_v4, 4, 6)),
                    url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua?icmp_type=" ..
                            icmp_type .. "&icmp_cod=" .. icmp_value ..
                            "&version=" .. ternary(is_v4, "4", "6"),
                },
                icmp_type  = tonumber(icmp_type),
                icmp_code  = tonumber(icmp_value),
                packets    = packets,
            }

            res[#res + 1] = entry
        end
    end
end

rest_utils.answer(rc, res)