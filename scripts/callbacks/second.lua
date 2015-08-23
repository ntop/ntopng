--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"

-- Toggle debug
local enable_second_debug = 0

ifnames = interface.getIfNames()
for _,ifname in pairs(ifnames) do
   a = string.ends(ifname, ".pcap")
   if(not(a)) then
      interface.select(ifname)
      ifstats = interface.getStats()
      dirs = ntop.getDirs()
      basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd")

      --io.write(basedir.."\n")
      if(not(ntop.exists(basedir))) then
	 if(enable_second_debug == 1) then io.write('Creating base directory ', basedir, '\n') end
	 ntop.mkdir(basedir)
      end

      -- Traffic stats
      makeRRD(basedir, ifname, "bytes", 1, ifstats.stats_bytes)
      makeRRD(basedir, ifname, "packets", 1, ifstats.stats_packets)
      makeRRD(basedir, ifname, "drops", 1, ifstats.stats_drops)

      -- General stats
      makeRRD(basedir, ifname, "num_hosts", 1, ifstats.stats_hosts)
      makeRRD(basedir, ifname, "num_flows", 1, ifstats.stats_flows)
      makeRRD(basedir, ifname, "num_http_hosts", 1, ifstats.stats_http_hosts)

      if(use_influx and (ifstats.stats_bytes > 0)) then
	 b = diff_value_influx(ifstats.name, "bytes", ifstats.stats_bytes)
	 p = diff_value_influx(ifstats.name, "packets", ifstats.stats_packets)
	 if(b > 0) then
	    if(num > 0) then header = header .. ',\n' end
	    header = header .. '['.. when .. ', "' .. ifstats.name .. '",' .. b .. ',' .. p .. ']'
	    num = num + 1
	 end
      end
   end
end -- for _,ifname in pairs(ifnames) do

if(use_influx) then
   header = header .. "\n]\n }\n]\n"
   --io.write(header)
   ntop.postHTTPJsonData(influx_user, influx_pwd, influx_url, header)
   save_curr_influx(cache_key)
end