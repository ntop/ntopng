--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "as_utils" -- needed for the function mac2record
local json = require("dkjson")

sendHTTPHeader('text/html; charset=iso-8859-1')

-- sendHTTPHeader('application/json')
interface.select(ifname)

local asn = tonumber(_GET["asn"])

interface.select(ifname)

local as = interface.getASInfo(asn)

local res = {}
if as ~= nil then
   res = as2record(as)
end

print(json.encode(res, nil))
