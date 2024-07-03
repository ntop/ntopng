--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ##############################################
-- #                Requirements                #
-- ##############################################

require "lua_utils"
local rest_utils = require("rest_utils")

-- ##############################################

--
-- Return interfaces informations
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/system/health/interfaces_stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

-- ##############################################
-- #                Functions                   #
-- ##############################################

-- Gets the interfaces informations

local function get_interfaces_info()
    local interfaces_info = {}

    for _,iface in pairs(interface.getIfNames()) do
        interface.select(iface)
        local ifstats = interface.getStats()

        if ifstats then

            local since_reset_drops = ifstats.stats_since_reset.drops
            local since_reset_packets = ifstats.stats_since_reset.packets
            local drops_pct = 0

            if (since_reset_drops > 0 or since_reset_packets > 0) then
                drops_pct = round(since_reset_drops / (since_reset_drops + since_reset_packets) * 100, 2)
            end

            local item = {
                engaged_alerts = ifstats.num_alerts_engaged,
                alerted_flows = ifstats.num_alerted_flows,
                local_hosts = ifstats.stats.local_host,
                remote_hosts = ifstats.stats.hosts - ifstats.stats.local_hosts,
                devices = ifstats.stats.devices,
                flows = ifstats.stats.flows,
                total_traffic = ifstats.stats_since_reset.bytes,
                total_packets = since_reset_packets,
                dropped_packets = drops_pct
            }
            interfaces_info[iface] = item
        end

    end

    return interfaces_info
end

-- ##############################################

-- Retrieves the REST API response

local function build_response()
    local interfaces_info = get_interfaces_info()
    rest_utils.answer(rest_utils.consts.success.ok,{interfaces_stats = interfaces_info})
end

-- ##############################################

build_response()

