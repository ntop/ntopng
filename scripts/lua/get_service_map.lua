--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

sendHTTPContentTypeHeader('application/json')

local rsp = {}
rsp.data  = {}

local p = interface.serviceMap(_GET["host"]) or {}

for k,v in pairs(p) do
   local row = {}
   local l4 = l4_proto_to_string(v.l4_proto)
   local port

   if(v.server_port == 0) then
      port = ""
   else
      port = v.server_port
   end

   if(l4 ~= v.l7_proto) then
      table.insert(row, l4 .. ":" .. v.l7_proto)
   else
      table.insert(row, v.l7_proto)
   end

   table.insert(row, builServiceMapHREF(v.client, v.vlan_id))
   table.insert(row, builServiceMapHREF(v.server, v.vlan_id))
   table.insert(row, v.vlan_id or 0)
   table.insert(row, port)
   table.insert(row, v.num_uses)
   table.insert(row, secondsToTime(os.time()-v.last_seen).. " "..i18n("details.ago"))
   table.insert(row, shortenString(v.info, 64))
   
   table.insert(rsp.data, row)
   table.insert(row, v.service_acceptance)
end

print(json.encode(rsp))