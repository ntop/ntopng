--
-- (C) 2019-24 - ntop.org
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

      for probe_ip, probe_info in pairsByKeys(probe_list or {}) do
	 table.insert(stats[iface], probe_info)
	 tprint(probe_list.exporters)
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, stats)
