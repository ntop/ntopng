--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

local interface_utils = {}

function interface_utils.get_pingable_interfaces()
    local res = {}

    local interfaces = ntop.getPingIfNames()

    for id, ifname in pairs(interfaces) do
    local custom_name = getHumanReadableInterfaceName(ifname)

    if isEmptyString(custom_name) then
        custom_name = nil
    end

    -- Note: returning in a format compatible with /lua/rest/v2/get/ntopng/interfaces.lua
    res[#res + 1] = {
        ifid = tonumber(id),
        ifname = ifname,
        name = custom_name or ifname,
        is_packet_interface = true,
        is_pcap_interface = false,
        is_zmq_interface = false,
    }
    end
    return res
    
end

return interface_utils