--
-- (C) 2017-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/test/?.lua;" .. package.path
local unittest = require("unittest"):new()
local if_stats = interface.getStats()

unittest:appendTest("Basic checks",
   function()
      unittest:assertEqual(if_stats.stats.hosts, 2, "Unexpected number of hosts")
      unittest:assertEqual(if_stats.stats.flows, 1, "Unexpected number of flows")
   end
)

unittest:appendTest("Dummy test",
   function()
      unittest:assertEqual(1, 1, "Math is an opinion")
   end
)

unittest:run()
