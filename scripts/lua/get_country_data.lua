--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "country_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')
interface.select(ifname)

local country = _GET["country"]

interface.select(ifname)

local country = interface.getCountryInfo(country)

local res = {}
if country ~= nil then
   res = country2record(getInterfaceId(ifname), country)
end

print(json.encode(res, nil))
