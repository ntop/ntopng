--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "vlan_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- sendHTTPHeader('application/json')
interface.select(ifname)

local vlan_id = tonumber(_GET["vlan"])

interface.select(ifname)

local vlan = interface.getVLANInfo(vlan_id)

local res = {}
if vlan ~= nil then
   res = vlan2record(getInterfaceId(ifname), vlan)
end

print(json.encode(res, nil))
