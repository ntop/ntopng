--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"


local ifid = _GET["ifid"]

if isEmptyString(ifid) then
    rest_utils.answer(rest_utils.consts.err.invalid_interface)
    return
end

local networks_stats = interface.getNetworksStats()

local res = {}
for n, ns in pairs(networks_stats) do
    res[#res+1] = {
        id = n,
        label = n,
        network_id = ns.network_id
    }

end

rest_utils.answer(rest_utils.consts.success.ok, res)