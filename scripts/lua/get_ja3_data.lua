--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "flow_utils"
require "historical_utils"
sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
host_info = url2hostinfo(_GET)

-- #####################################################################

function revFP(a,b)
   return (a.num_uses > b.num_uses)
end

-- #####################################################################

if(host_info["host"] ~= nil) then
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
end

if(stats ~= nil) then
   local fp = stats["ssl_fingerprint"]
   
   num = 0
   max_num = 50 -- set a limit
   for key,value in pairsByValues(fp, revFP) do
      if(num == max_num) then
	 break
      else
	 num = num + 1
	 print('<tr><td><A HREF="https://sslbl.abuse.ch/ja3-fingerprints/'..key..'">'..key..'</A> <i class="fa fa-external-link"></i></td>')
	 print('<td align=left nowrap>'..value.app_name..'</td>')
	 print('<td align=right>'..formatValue(value.num_uses)..'</td>')
	 print('</tr>\n')
      end
   end
end
