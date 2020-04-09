--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
require "flow_utils"
require "historical_utils"
local companion_interface_utils = require "companion_interface_utils"

local available_fingerprints = {
   ja3 = {
      stats_key = "ja3_fingerprint",
      href = function(fp) return '<A HREF="https://sslbl.abuse.ch/ja3-fingerprints/'..fp..'" target="_blank">'..fp..'</A>  <i class="fas fa-external-link-alt"></i>' end
   },
   hassh = {
      stats_key = "hassh_fingerprint",
      href = function(fp) return fp end
   }
}

sendHTTPContentTypeHeader('text/html')

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local fingerprint_type = _GET["fingerprint_type"]

-- #####################################################################

function revFP(a,b)
   return (a.num_uses > b.num_uses)
end

-- #####################################################################

if(host_info["host"] ~= nil) then
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
end

if stats and available_fingerprints[fingerprint_type] then
   local fk = available_fingerprints[fingerprint_type]["stats_key"]
   local fp = stats[fk]

   num = 0
   max_num = 50 -- set a limit
   for key,value in pairsByValues(fp, revFP) do
      if(num == max_num) then
	 break
      else
	 num = num + 1
	 print('<tr><td>'..available_fingerprints[fingerprint_type]["href"](key)..'</td>')
	 if not isEmptyString(companion_interface_utils.getCurrentCompanion(ifid)) then
	    print('<td align=left nowrap>'..value.app_name..'</td>')
	 end
	 print('<td align="right">'..formatValue(value.num_uses)..'</td>')
	 print('</tr>\n')
      end
   end
end
