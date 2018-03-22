--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "mac_utils" -- needed for the function mac2record
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')
interface.select(ifname)

local host_info = url2hostinfo(_GET)

interface.select(ifname)

local host = interface.getMacInfo(host_info["host"])

local res = {}
if host ~= nil then
   res = mac2record(host)
end

print(json.encode(res, nil))
