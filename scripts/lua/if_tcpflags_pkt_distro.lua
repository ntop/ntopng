--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)
ifstats = interface.getStats()

what = ifstats["pktSizeDistribution"]

local pkt_distribution = {
   ['syn'] = 'SYN',
   ['synack'] = 'SYN/ACK',
   ['finack'] = 'FIN/ACK',
   ['rst'] = 'RST',
}


print "[\n"
num = 0
for key, value in pairs(what) do
   if(pkt_distribution[key] ~= nil) then
      if(num > 0) then
	 print ",\n"
      end
            
      print("\t { \"label\": \"" .. pkt_distribution[key] .."\", \"value\": ".. value .." }") 
      num = num + 1
   end
end

if(num == 0) then
   print("\t, { \"label\": \"Other\", \"value\": 100 }") 
end

print "\n]"

