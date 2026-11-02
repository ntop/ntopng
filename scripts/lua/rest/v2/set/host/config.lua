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

local ifstats = interface.getStats()
local host = interface.getHostInfo(host_info["host"], host_info["vlan"])
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

    -- Journal of the assets: the tags set/unset by the user on an active host
    -- (that will reach its asset with the next snapshot of the host).
    -- NOTE: same host as interface.setHostTags (VLAN in the host string only)
    if ntop.isEnterpriseL and ntop.isEnterpriseL() then
        local ip, vlan = string.match(host_info["host"], "^([^@]+)@?(%d*)$")

        vlan = tonumber(vlan) or 0

        if ip and interface.getHostInfo(ip, vlan) then
            package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
            local asset_utils = require "asset_utils"
            local assets_journal = require "assets_journal"

            asset_utils.journalHostUserTags(interface.getId(), ip, vlan,
                interface.getUserDefinedHostTags(host_info["host"]), tags_bitmap, assets_journal.currentUser())
        end
    end

    interface.setHostTags(host_info["host"], tags_bitmap)
end

local rc = rest_utils.consts.success.ok
rest_utils.answer(rc)

