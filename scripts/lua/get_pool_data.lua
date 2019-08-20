--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')

local pool = tonumber(_GET["pool"])

local n = interface.getHostPoolStats(pool)
local res = {}

for k, v in pairs(n) do
   res = host_pools_utils.hostpool2record(interface.getStats()["id"], k, v)
   break
end

print(json.encode(res, nil))
