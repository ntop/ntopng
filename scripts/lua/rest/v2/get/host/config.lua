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

local host = interface.getHostInfo(host_info["host"], host_info["vlan"])
local ifstats = interface.getStats()
local host_key = hostinfo2hostkey(host_info)

local rsp = {
    alias = getHostAltName(host_info),
    notes = getHostNotes(host_info),
    host_pool_id = host["host_pool_id"],
    host_pool_match = host["host_pool_match"],
    has_traffic_policies = ifstats.inline and (host.localhost or host.systemhost),
    drop_traffic = ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_key)
}

local rc = rest_utils.consts.success.ok
rest_utils.answer(rc, rsp)

