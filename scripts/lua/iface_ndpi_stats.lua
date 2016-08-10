--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)
host_info = url2hostinfo(_GET)

if(_GET["breed"] == "true") then
   show_breed = true
else
   show_breed = false
end

if(_GET["mode"] == "sinceStartup") then
   stats = interface.getStats()
   elseif(_GET["mode"] == "count") then
   stats = interface.getnDPIFlowsCount()
   elseif(host_info["host"] == nil) then
   stats = interface.getnDPIStats()
else
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
end

print "[\n"

if(stats ~= nil) then
   tot = 0
   _ifstats = {}

   if(_GET["mode"] == "count") then
      tot = 0

      for k, v in pairs(stats) do
	 tot = tot + v
	 stats[k] = tonumber(v)
	 --  print(k.."="..v.."\n,")
      end

      threshold = (tot * 3) / 100	
      num = 0	
      for k, v in pairsByValues(stats, rev) do
	 if((num < 5) and (v > threshold)) then
	    if(num > 0) then print(", ") end
	    print("\t { \"label\": \"" .. k .."\", \"value\": ".. v .." }")
	    num = num + 1
	    tot = tot - v
	 else
	    break
	 end
      end

      if(tot > 0) then
	 if(num > 0) then print(", ") end
	 print("\t { \"label\": \"Other\", \"value\": ".. tot .." }")
	 
      end

      print "]\n"
      return
   end
   
   if(show_breed) then
      __ifstats = {}
      
      for key, value in pairs(stats["ndpi"]) do
	 b = stats["ndpi"][key]["breed"] 

	 traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]

	 if(__ifstats[b] == nil) then
	    __ifstats[b] = traffic
	 else
	    __ifstats[b] = __ifstats[b] + traffic
	 end
      end

      for key, value in pairs(__ifstats) do
	 --print(key.."="..value.."<p>\n")
	 _ifstats[value] = key
	 tot = tot + value
      end

   else
      for key, value in pairs(stats["ndpi"]) do
	 --    print("->"..key.."\n")
	 traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]
	 
	 if(show_breed) then
	    _ifstats[traffic] = stats["ndpi"][key]["breed"]
	 else
	    _ifstats[traffic] = key
	 end
	 
	 --print(key.."="..traffic)
	 tot = tot + traffic
      end
   end

   -- Print up to this number of entries
   max_num_entries = 5   

   -- Print entries whose value >= 3% of the total
   threshold = (tot * 3) / 100

   num = 0
   accumulate = 0
   for key, value in pairsByKeys(_ifstats, rev) do
      if(key < threshold) then
	 break
      end

      if(num > 0) then
	 print ",\n"
      end

      if(host_info["host"] == nil) then
         print("\t { \"label\": \"" .. value .."\", \"url\": \""..ntop.getHttpPrefix().."/lua/flows_stats.lua?application="..value.."\", \"value\": ".. key .." }")
      else
         print("\t { \"label\": \"" .. value .."\", \"value\": ".. key .." }")
      end
      accumulate = accumulate + key
      num = num + 1

      if(num == max_num_entries) then
	 break
      end
   end

   if(tot == 0) then
      tot = 1
   end

   -- In case there is some leftover do print it as "Other"
   if(accumulate < tot) then
      if(num > 0) then
	 print (",\n")
      end

      print("\t { \"label\": \"Other\", \"value\": ".. (tot-accumulate) .." }")
   end
end

print "\n]"
