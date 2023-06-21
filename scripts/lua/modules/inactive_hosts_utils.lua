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
function inactive_hosts_utils.getInactiveHosts(ifid, filters)
    local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
    local available_keys = ntop.getHashKeysCache(redis_hash) or {}
    local networks_stats = interface.getNetworksStats()
    local host_list = {}

    for redis_key, _ in pairs(available_keys) do
        local host_info_json = ntop.getHashCache(redis_hash, redis_key)
        local network_name = ""

        if not isEmptyString(host_info_json) then
            local host_info = json.decode(host_info_json)

            for filter, value in pairs(filters) do
                if tostring(host_info[filter]) ~= tostring(value) then
                    goto skip
                end
            end
           
            local mac_manufacturer = ntop.getMacManufacturer(host_info.mac) or {}

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
                serial_key = redis_key,
                manufacturer = mac_manufacturer.extended
            }
        end

        ::skip::
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

-- ##########################################

-- This function return a list of inactive hosts, with all the informations
function inactive_hosts_utils.getVLANFilters(ifid)
    local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
    local available_keys = ntop.getHashKeysCache(redis_hash) or {}
    local vlan_list = {}
    local rsp = {}

    for redis_key, _ in pairs(available_keys) do
        local host_info_json = ntop.getHashCache(redis_hash, redis_key)

        if not isEmptyString(host_info_json) then
            local host_info = json.decode(host_info_json)
            if not(vlan_list[host_info.vlan]) then
                vlan_list[host_info.vlan] = 1
            else
                vlan_list[host_info.vlan] = vlan_list[host_info.vlan] + 1
            end
        end
    end

    for vlan, count in pairsByKeys(vlan_list) do
        local vlan_name = ''
        if vlan == 0 then
            vlan_name = i18n('no_vlan')
        else
            vlan_name = getFullVlanName(vlan)
        end
        rsp[#rsp + 1] = {
            count = count,
            key = "vlan_id",
            value = vlan,
            label = tostring(vlan_name)
        }
    end
    table.insert(rsp, 1, {
        key = "vlan_id",
        value = "",
        label = i18n('flows_page.all_vlan_ids')
    })

    return rsp
end

-- ##########################################

-- This function return a list of inactive hosts, with all the informations
function inactive_hosts_utils.getNetworkFilters(ifid)
    local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
    local available_keys = ntop.getHashKeysCache(redis_hash) or {}
    local networks_stats = interface.getNetworksStats()
    local network_list = {}
    local rsp = {}

    for redis_key, _ in pairs(available_keys) do
        local host_info_json = ntop.getHashCache(redis_hash, redis_key)
        local network_name = ""

        if not isEmptyString(host_info_json) then
            local host_info = json.decode(host_info_json)

            if not(network_list[host_info.network]) then
                network_list[host_info.network] = 1
            else
                network_list[host_info.network] = network_list[host_info.network] + 1
            end
        end
    end

    for network, count in pairsByKeys(network_list) do
        local network_name
        for n, ns in pairs(networks_stats) do
            if ns.network_id == tonumber(network) then
                network_name = getFullLocalNetworkName(ns.network_key)
            end
        end

        rsp[#rsp + 1] = {
            count = count,
            key = "network",
            value = network,
            label = tostring(network_name or network)
        }
    end
    table.insert(rsp, 1, {
        key = "network",
        value = "",
        label = i18n('flows_page.all_networks')
    })

    return rsp
end

-- ##########################################

return inactive_hosts_utils
