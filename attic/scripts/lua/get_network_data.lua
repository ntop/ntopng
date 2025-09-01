--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local network_formatter = require "network_formatter"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')

local network = tonumber(_GET["network"])

local network_stats = interface.getNetworkStats(network) or {}
local res = {}

for _, v in pairs(network_stats) do
   res = network_formatter.network2record(interface.getId(), v)
   break
end

print(json.encode(res, nil))
