--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local os_data_utils = require "os_data_utils" -- needed for the function mac2record
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')
interface.select(ifname)

local os = tonumber(_GET["os"])

interface.select(ifname)

local os = interface.getOSInfo(os)

local res = {}
if os ~= nil then
   res = os_data_utils.os2record(getInterfaceId(ifname), os)
end

print(json.encode(res, nil))
