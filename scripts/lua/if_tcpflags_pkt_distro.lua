--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
host_info = url2hostinfo(_GET)

if(host_info["host"] ~= nil) then
   local stats = interface.getHostInfo(host_info["host"],host_info["vlan"])
   if stats == nil then return end

   -- join sent and rcvd
   local sent_stats = stats["pktStats.sent"]
   local rcvd_stats = stats["pktStats.recv"]
   what = {}

   for k, _ in pairs(sent_stats) do
      what[k] = sent_stats[k] + rcvd_stats[k]
   end
else
   local stats = interface.getStats()
   if stats == nil then return end

   what = stats["pktSizeDistribution"]
end

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

