--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
require "lua_utils"
local host_pools = require "host_pools"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')

local pool = tonumber(_GET["pool"])

-- Instantiate host pools
local host_pools_instance = host_pools:create()

local n = interface.getHostPoolStats(pool)
local res = {}

for k, v in pairs(n) do
   res = host_pools_instance:hostpool2record(interface.getId(), k, v)
   break
end

print(json.encode(res, nil))
