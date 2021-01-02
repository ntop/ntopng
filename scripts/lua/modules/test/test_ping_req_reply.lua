--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/test/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require "dkjson"
local unittest = require("unittest"):new()

unittest:appendTest("Basic checks",
   function()
      local if_stats = interface.getStats()
      unittest:assertEqual(if_stats.stats.hosts, 2, "Unexpected number of hosts")
      unittest:assertEqual(if_stats.stats.flows, 1, "Unexpected number of flows")
   end
)

unittest:appendTest("REST API: flows",
   function()
      local url = "http://localhost:3000"..ntop.getHttpPrefix().."/lua/get_flows_data.lua"
      local resp = ntop.httpGet(url)
      local content = resp["CONTENT"]
      local jcontent = json.decode(content)

      unittest:assertEqual(jcontent.totalRows, 1, string.format("Unexpected number of rows [%s]", url))
      unittest:assertEqual(table.len(jcontent.data), 1, string.format("Unexpected number of elements in response [%s]", url))

      local flow = jcontent.data[1]
      unittest:assertEqual(flow.column_vlan, 0, string.format("Unexpected vlan [%s]", url))
      unittest:assertEqual(flow.column_bytes, "196 Bytes", string.format("Unexpected number of bytes [%s]", url))
      unittest:assertEqual(flow.key, 3249079264, string.format("Unexpected flow key [%s]", url))
   end
)

unittest:appendTest("REST API: hosts",
   function()
      local url = "http://localhost:3000"..ntop.getHttpPrefix().."/lua/get_hosts_data.lua?sortColumn=column_ip"
      local resp = ntop.httpGet(url)
      local content = resp["CONTENT"]
      local jcontent = json.decode(content)

      unittest:assertEqual(jcontent.totalRows, 2, string.format("Unexpected number of rows [%s]", url))
      unittest:assertEqual(table.len(jcontent.data), 2, string.format("Unexpected number of elements in response [%s]", url))

      local host = jcontent.data[1]
      unittest:assertEqual(host.column_num_flows, "1", string.format("Unexpected number of flows [%s]", url))
      unittest:assertEqual(host.column_vlan, "0", string.format("Unexpected vlan [%s]", url))
      unittest:assertEqual(host.column_alerts, "0", string.format("Unexpected number of alerts [%s]", url))
      unittest:assertEqual(host.key, "192__168__2__222", string.format("Unexpected key [%s]", url))

      host = jcontent.data[2]
      unittest:assertEqual(host.column_num_flows, "1", string.format("Unexpected number of flows [%s]", url))
      unittest:assertEqual(host.column_vlan, "0", string.format("Unexpected vlan [%s]", url))
      unittest:assertEqual(host.column_alerts, "0", string.format("Unexpected number of alerts [%s]", url))
      unittest:assertEqual(host.key, "1__1__1__1", string.format("Unexpected key [%s]", url))
   end
)

unittest:appendTest("Dummy test",
   function()
      unittest:assertEqual(1, 1, "Math is an opinion")
   end
)

unittest:run()
