--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ifid = getInterfaceId(ifname)
epoch = _GET["epoch"]

if (epoch == nil) then epoch = os.time() end
epoch = tonumber(epoch)

epoch_now = ntop.getMinuteRealEpoch(ifid, epoch)
if ((epoch_now == 0) or (epoch_now == nil)) then
  epoch_now = os.time()
end
epoch_before = ntop.getMinuteRealEpoch(ifid, epoch_now - 60)
if (epoch_before == 0) then
  epoch_before = os.time() - 60
end

print(tostring(epoch_now).." "..tostring(epoch_before))
