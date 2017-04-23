--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "vlan_utils"
local json = require("dkjson")

sendHTTPHeader('text/html; charset=iso-8859-1')

-- sendHTTPHeader('application/json')
interface.select(ifname)

local vlan_id = tonumber(_GET["vlan"])

interface.select(ifname)

local vlan = interface.getVLANInfo(vlan_id)

local res = {}
if vlan ~= nil then
   res = vlan2record(vlan)
end

print(json.encode(res, nil))
