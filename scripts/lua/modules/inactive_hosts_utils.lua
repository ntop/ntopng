--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require("lua_utils")
local json = require("dkjson")
local discover = require "discover_utils"

local OFFLINE_LOCAL_HOSTS_KEY = "ntopng.hosts.offline.ifid_%s"
local inactive_hosts_utils = {}

-- ##########################################

-- This function return a list of inactive hosts, with all the informations
function inactive_hosts_utils.getInactiveHosts(ifid)
    local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
    local available_keys = ntop.getHashKeysCache(redis_hash) or {}
    local networks_stats = interface.getNetworksStats()
    local host_list = {}

    for redis_key, _ in pairs(available_keys) do
        local host_info_json = ntop.getHashCache(redis_hash, redis_key)
        local network_name = ""

        if not isEmptyString(host_info_json) then
            local host_info = json.decode(host_info_json)

            for n, ns in pairs(networks_stats) do
                if ns.network_id == tonumber(host_info.network) then
                    network_name = getFullLocalNetworkName(ns.network_key)
                end
            end

            host_list[#host_list + 1] = {
                ip_address = host_info.ip,
                mac_address = host_info.mac,
                vlan = getFullVlanName(host_info.vlan),
                vlan_id = host_info.vlan,
                name = host_info.name,
                last_seen = host_info.last_seen,
                first_seen = host_info.first_seen,
                epoch_end = host_info.last_seen,
                epoch_begin = host_info.first_seen,
                device_id = host_info.device_type,
                device_type = discover.devtype2string(host_info.device_type),
                network_id = host_info.network,
                network = network_name,
                serial_key = redis_key
            }
        end
    end

    return host_list
end

-- ##########################################

-- This function return the info of a specific inactive host, given the serialization (redis) key
function inactive_hosts_utils.getInactiveHostInfo(ifid, serial_key)
    local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
    local host_info_json = ntop.getHashCache(redis_hash, serial_key)

    if not isEmptyString(host_info_json) then
        local host_info = json.decode(host_info_json)

        return host_info
    end

    return nil
end

-- ##########################################

function inactive_hosts_utils.getInactiveHostsNumber(ifid)
    local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
    local available_keys = ntop.getHashKeysCache(redis_hash) or {}

    return table.len(available_keys)
end

return inactive_hosts_utils
