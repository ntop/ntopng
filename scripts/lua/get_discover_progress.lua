--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local discover = require "discover_utils"
local rest_utils = require "rest_utils"

local ifId = _GET["ifid"]

local discovery_requested = discover.networkDiscoveryRequested(ifId)
local discover_info = discover.discover2table(ifname)

local res = {
   discovery_requested = discovery_requested,
   progress = discover.getDiscoveryProgress(),
   ghost_found = true,
   too_many_devices = discover_info["too_many_devices_discovered"],
   last_network_discovery = i18n("discover.network_discovery_datetime")..": "..formatEpoch(discover_info["discovery_timestamp"]), 
}

rest_utils.answer(rest_utils.consts.success.ok, res)
