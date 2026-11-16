--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
require "lua_utils_get"
require "lua_utils_gui"
local rest_utils = require "rest_utils"
local host_info = url2hostinfo(_GET)

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_found)
    return
end

if isEmptyString(host_info.host) then
    rest_utils.answer(rest_utils.consts.err.invalid_host)
    return
end

-- The interface of the request (optional: otherwise the one of the session)
local ifid = _GET["ifid"]

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

local rsp = {
    alias = getHostAltName(host_info),
    notes = getHostNotes(host_info),
    host_pool_id = host["host_pool_id"],
    has_traffic_policies = ifstats.inline and (host.localhost or host.systemhost),
    drop_traffic = ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_key),
    -- NOTE: the host with its VLAN (in the host string)
    tags = interface.getHostTags(host_key),
    user_tags = interface.getUserDefinedHostTags(host_key)
}

local rc = rest_utils.consts.success.ok
rest_utils.answer(rc, rsp)

