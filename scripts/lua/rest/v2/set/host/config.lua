--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
require "label_utils"
require "lua_utils_get"
require "lua_utils_gui"
local rest_utils = require "rest_utils"
local host_info = url2hostinfo(_POST)

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_found)
    return
end

if isEmptyString(host_info.host) then
    rest_utils.answer(rest_utils.consts.err.invalid_host)
    return
end

-- The interface of the request (optional: otherwise the one of the session)
local ifid = _POST["ifid"]

if not isEmptyString(ifid) then
    interface.select(tostring(ifid))

    -- interface.select silently falls back to an allowed interface
    if tostring(interface.getId()) ~= tostring(ifid) then
        rest_utils.answer(rest_utils.consts.err.invalid_interface)
        return
    end
end

local host = interface.getHostInfo(host_info["host"], host_info["vlan"])

-- The host is not active on the interface
if not host then
    rest_utils.answer(rest_utils.consts.err.not_found)
    return
end

local ifstats = interface.getStats()
local host_key = hostinfo2hostkey(host_info)
local drop_host_traffic = _POST["drop_host_traffic"]

-- Traffic Policy
if (ifstats.inline and (host.localhost or host.systemhost)) then
    if (drop_host_traffic ~= "1") then
        ntop.delHashCache("ntopng.prefs.drop_host_traffic", host_key)
    else
        ntop.setHashCache("ntopng.prefs.drop_host_traffic", host_key, "true")
    end

    interface.updateHostTrafficPolicy(host_info["host"], host_info["vlan"])
end

-- Host Pool
local host_pool_id = _POST["pool"]
if host_pool_id ~= tostring(host["host_pool_id"]) then
    local host_pools = require "host_pools"

    local host_pools_instance = host_pools:create()
    local key = ""

    if host["host_pool_match"] == "mac" then
        key = host["mac"]
    else
        key = host2member(host_info["host"], host_info["vlan"])
    end
    
    if host_pools_instance:bind_member(key, tonumber(host_pool_id)) then
        ntop.reloadHostPools()
    else
        host_pool_id = nil
    end
end

if (_POST["custom_name"] ~= nil) and isAdministrator() then
    setHostAltName(host_info, _POST["custom_name"])
end

if (_POST["custom_notes"] ~= nil) and isAdministrator() then
    setHostNotes(host_info, _POST["custom_notes"])
end

if (_POST["host_tags_bitmap"] ~= nil) and isAdministrator() then
    local tags_bitmap = tonumber(_POST["host_tags_bitmap"]) or 0
    local ip, vlan = host_info["host"], tonumber(host_info["vlan"]) or 0
    -- The host of the request (interface.setHostTags takes the VLAN in the
    -- host string)
    local host_key = hostinfo2hostkey({ host = ip, vlan = vlan })
    -- The hosts with the same IP on the other VLANs of its asset are the same
    -- device (the VLAN is not part of the key of the asset): their tags are
    -- set as well, so that the asset and its hosts agree
    local vlans = { vlan }

    if ntop.isEnterpriseM and ntop.isEnterpriseM() then
        package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
        local asset_utils = require "asset_utils"

        vlans = asset_utils.getIpAssetVlans(interface.getId(), ip, vlan)

        -- Journal of the assets: the tags set/unset by the user on an active
        -- host (that will reach its asset with the next snapshot of the host)
        if ntop.isEnterpriseL and ntop.isEnterpriseL() and interface.getHostInfo(ip, vlan) then
            local assets_journal = require "assets_journal"

            asset_utils.journalHostUserTags(interface.getId(), ip, vlan,
                interface.getUserDefinedHostTags(host_key), tags_bitmap, assets_journal.currentUser())
        end
    end

    for _, v in ipairs(vlans) do
        interface.setHostTags(hostinfo2hostkey({ host = ip, vlan = v }), tags_bitmap)
    end
end

local rc = rest_utils.consts.success.ok
rest_utils.answer(rc)

