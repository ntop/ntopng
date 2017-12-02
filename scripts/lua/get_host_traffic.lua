--
-- (C) 2014-15-15 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

local host_ip = _GET["host"]

interface.select(ifname)
local host = interface.getHostInfo(host_ip)
local value = 0

if(host ~= nil) then
   value = host["packets.sent"]+host["packets.rcvd"]
end

print(' { "value": ' .. value .. ' } ')
