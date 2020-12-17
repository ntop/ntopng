--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local ifs = interface.getStats()

sendHTTPHeader('application/json')

local ifid = ifs.id
local REDIS_KEY = string.format("ntopng.prefs.service_map.%d.graph", ifid)

-- prepare response for the request
local res = {}
-- get the node position
local graph_view = _POST['JSON']

ntop.setPref(REDIS_KEY, graph_view)

res.success = true
res.message = "The graph view has been saved!"

print(json.encode(res))
