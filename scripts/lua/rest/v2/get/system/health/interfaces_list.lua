--
-- (C) 2013-26 - ntop.org
--
-- Health > Interfaces Status: one record per monitored interface (raw counters)
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
local rest_utils = require("rest_utils")

-- -1: the system interface
if not ntop.isAllowedInterface(-1) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}

for ifid, ifname in pairs(interface.getIfNames()) do
   interface.select(ifname)
   local ifstats = interface.getStats()

   if ifstats then
      local s = ifstats.stats
      local since_reset = ifstats.stats_since_reset

      res[#res + 1] = {
         ifid = ifstats.id,
         name = getHumanReadableInterfaceName(tostring(ifstats.id)),
         engaged_alerts = ifstats.num_alerts_engaged,
         alerted_flows = ifstats.num_alerted_flows,
         local_hosts = s.local_hosts,
         remote_hosts = s.hosts - s.local_hosts,
         devices = s.devices,
         flows = s.flows,
         bytes = since_reset.bytes,
         packets = since_reset.packets,
         drops = since_reset.drops,
      }
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
