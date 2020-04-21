--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local datasources_utils = require("datasources_utils")
local datamodel = require("datamodel_utils")

local function reportError(msg)
    print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local ifid       = _GET["ifid"] or 0
local if_name    = getInterfaceName(ifid)
local chart_type = _GET["chart_type"] or "size"

interface.select(ifname)
local ifstats = interface.getStats()
local m = nil

local m = datamodel:create({"IPv4", "IPv6"})
m:appendRow(when, "IP Version Distribution", { ifstats.eth.IPv4_packets, ifstats.eth.IPv6_packets })
return(m)
