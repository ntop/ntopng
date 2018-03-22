--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
local ifstats = interface.getStats()
local distr_type = _GET["distr"]

if((distr_type == nil) or (distr_type == "size")) then
   what = ifstats["pktSizeDistribution"]
elseif distr_type == "ipver" then
   print "[\n"
   print("\t { \"label\": \"IPv6\", \"value\": ".. ifstats.eth.IPv6_packets .." },")
   print("\t { \"label\": \"IPv4\", \"value\": ".. ifstats.eth.IPv4_packets .." }")
   print "\n]"
   return
end

local pkt_distribution = {
   ['upTo64'] = '<= 64',
   ['upTo128'] = '64 <= 128',
   ['upTo256'] = '128 <= 256',
   ['upTo512'] = '256 <= 512',
   ['upTo1024'] = '512 <= 1024',
   ['upTo1518'] = '1024 <= 1518',
   ['upTo2500'] = '1518 <= 2500',
   ['upTo6500'] = '2500 <= 6500',
   ['upTo9000'] = '6500 <= 9000',
   ['above9000'] = '> 9000'
}

local tot = 0
for key, value in pairs(what) do
   tot = tot + value
end

local threshold = (tot * 5) / 100

print "[\n"
num = 0
local sum = 0
for key, value in pairs(what) do
   if(value > threshold) then
      if(pkt_distribution[key] ~= nil) then
	 if(num > 0) then
	    print ",\n"
	 end
	 	 
	 print("\t { \"label\": \"" .. pkt_distribution[key] .."\", \"value\": ".. value .." }") 
	 num = num + 1
	 sum = sum + value
      end
   end
end

if(sum < tot) then
   print("\t, { \"label\": \"Other\", \"value\": ".. (tot-sum) .." }") 
end

print "\n]"

