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

local p = interface.periodicityStats() or {}

local cache = {}

function buildHostHREF(ip_address)
   local stats = cache[ip_address]

   if(stats == nil) then
      stats = interface.getHostInfo(ip_address)
      cache[ip_address] = { stats = stats }
   else
      stats = stats.stats
   end

   if(stats == nil) then
      return(ip_address)
   else
      local name = stats.name

      if((name == nil) or (name == "")) then name = ip_address end
      return('<A HREF="'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..ip_address..'">'..name..'</A>')
   end
end

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
      table.insert(row, l4 .. "." .. v.l7_proto)
   else
      table.insert(row, v.l7_proto)
   end

   table.insert(row, buildHostHREF(v.client))
   table.insert(row, buildHostHREF(v.server))
   table.insert(row, port)
   table.insert(row, v.num_periodic_loops_accounted)
   table.insert(row, v.frequency)
   table.insert(row, shortenString(v.info, 64))

   table.insert(rsp.data, row)
end

print(json.encode(rsp))
