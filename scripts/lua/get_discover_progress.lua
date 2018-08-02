--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local discover = require "discover_utils"

local ifId = _GET["ifid"]

local discovery_requested = discover.networkDiscoveryRequested(ifId)

sendHTTPHeader('application/json')

local res = {
   discovery_requested = discovery_requested,
   progress = discover.getDiscoveryProgress()
}

print(json.encode(res, nil))
