--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
local host_info = url2hostinfo(_GET)

local ndpi_protos = interface.getnDPIProtocols()
local show_ndpi_category = false
local show_breed = false

local function getAppUrl(app)
   return ternary(ndpi_protos[app] ~= nil, "\"url\": \""..ntop.getHttpPrefix().."/lua/flows_stats.lua?application="..app.."\", ", "")
end

if(_GET["breed"] == "true") then show_breed = true end
if(_GET["ndpi_category"] == "true") then show_ndpi_category = true end

local tot = 0
local _ifstats = {}

if(_GET["ndpistats_mode"] == "sinceStartup") then
   stats = interface.getStats()
   tot = stats.stats.bytes
elseif(_GET["ndpistats_mode"] == "count") then
   stats = interface.getnDPIFlowsCount()
else
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
   if(stats ~= nil) then
      tot = stats["bytes.sent"] + stats["bytes.rcvd"]
   end
end

print "[\n"

if(stats ~= nil) then

   if(_GET["ndpistats_mode"] == "count") then
      tot = 0

      for k, v in pairs(stats) do
	 tot = tot + v
	 stats[k] = tonumber(v)
	 --  print(k.."="..v.."\n,")
      end

      local threshold = (tot * 3) / 100
      local num = 0
      for k, v in pairsByValues(stats, rev) do
	 if((num < 5) and (v > threshold)) then
	    if(num > 0) then print(", ") end
	    print("\t { \"label\": \"" .. k .."\"," .. getAppUrl(k) .. " \"value\": ".. v .." }")
	    num = num + 1
	    tot = tot - v
	 else
	    break
	 end
      end

      if(tot > 0) then
	 if(num > 0) then print(", ") end
	 print("\t { \"label\": \"Other\", \"value\": ".. tot .." }")
      elseif(num == 0) then
	 print("\t { \"label\": \"No Flows\", \"value\": 0 }")
      end

      print "]\n"
      return
   end

   if(show_breed) then
      local breed_stats = {}

      for key, value in pairs(stats["ndpi"]) do
	 local b = stats["ndpi"][key]["breed"]

	 local traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]

	 if(breed_stats[b] == nil) then
	    breed_stats[b] = traffic
	 else
	    breed_stats[b] = breed_stats[b] + traffic
	 end
      end

      for key, value in pairs(breed_stats) do
	 --print(key.."="..value.."<p>\n")
	 _ifstats[key] = value
      end

   elseif(show_ndpi_category) then
      local ndpi_category_stats = {}

      for key, value in pairs(stats["ndpi_categories"]) do
	 local traffic = value["bytes"]

	 if(ndpi_category_stats[key] == nil) then
	    ndpi_category_stats[key] = traffic
	 else
	    ndpi_category_stats[key] = ndpi_category_stats[key] + traffic
	 end
      end

      for key, value in pairs(ndpi_category_stats) do
	 --print(key.."="..value.."<p>\n")
	 _ifstats[key] = value
      end

   else
      -- Add ARP to stats
      if(stats["eth"] ~= nil) then
	 arpBytes = stats["eth"]["ARP_bytes"]
      else
	 arpBytes = 0
      end

      if(arpBytes > 0) then
	_ifstats["ARP"] = arpBytes
      end

      for key, value in pairs(stats["ndpi"]) do
	 --print("->"..key.."\n")

	 local traffic = value["bytes.sent"] + value["bytes.rcvd"]
	 if(key == "Unknown") then
	   traffic = traffic - arpBytes
	 end

	 if(traffic > 0) then
	   if(show_breed) then
	      _ifstats[value["breed"]] = traffic
	   else
	      _ifstats[key] = traffic
	   end

	   --print(key.."="..traffic)
	 end
      end
   end

   -- Print up to this number of entries
   local max_num_entries = 5

   -- Print entries whose value >= 3% of the total
   local threshold = (tot * 3) / 100

   local num = 0
   local accumulate = 0

   for key, value in pairsByValues(_ifstats, rev) do
      -- print("["..value.."/"..key.."]\n")
      if(value < threshold) then
	 break
      end

      if(num > 0) then
	 print ",\n"
      end

      if(host_info["host"] == nil) then
	 print("\t { \"label\": \"" .. key .."\"," .. getAppUrl(key) .. " \"value\": ".. value .." }")
      else
	 local duration

	 if(stats["ndpi"][key] ~= nil) then
	    duration = stats["ndpi"][key]["duration"]
	 else
	    duration = 0
	 end

	 print("\t { \"label\": \"" .. key .."\", \"value\": ".. value ..", \"duration\": ".. duration .." }")
      end

      accumulate = accumulate + value
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
