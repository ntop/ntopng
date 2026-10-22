--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local names = interface.getIfNames()
local stats = {}


for _,iface in pairs(names) do
   local ifstats
   
   interface.select(iface)
   ifstats  = interface.getStats()

   stats[iface] = {}
   
   for interface_id, probe_list in pairs(ifstats.probes or {}) do
      stats[iface] = {}

      local iface_stats = stats[iface]
      for probe_ip, probe_info in pairsByKeys(probe_list or {}) do
	 iface_stats[#iface_stats + 1] = probe_info
      end
   end
end

if #stats == 0 then
   stats = {"No flow collectors associated with ntopng"}
end

rest_utils.answer(rest_utils.consts.success.ok, stats)
