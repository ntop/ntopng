--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/html')

if(_GET["csrf"] ~= nil) then
interface_name = _GET["id"]
from = tonumber(_GET["from"])
to = tonumber(_GET["to"])
epoch = tonumber(_GET["epoch"])

ret = false

if (interface_name ~= nil) then
  interface_id = tonumber(interface.name2id(interface_name))
end
if ((from ~= nil) and (to ~= nil) and (interface_id ~= nil)) then
--  io.write(from .. '-' .. to.. '-' .. interface_id .. '\n')
  ret = interface.loadHistoricalInterval(from,to,interface_id)
end

if (ret)  then
  print "{ \"result\" : \"0\"}";
else
  print ( "{ \"result\" : \"-1\"}" );
end
end