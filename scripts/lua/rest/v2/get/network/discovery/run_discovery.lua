--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover = require "discover_utils"
local rest_utils = require "rest_utils"

local ifid = tostring(_GET["ifid"]) or interface.getId()

discover.requestNetworkDiscovery(ifid)
local discovery_requested = discover.networkDiscoveryRequested(ifid)

rest_utils.answer(rest_utils.consts.success.ok)