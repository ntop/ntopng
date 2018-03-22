--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
hosts_stats = interface.getHostsInfo(false, "column_traffic")
hosts_stats = hosts_stats["hosts"]

ajax_format = _GET["ajax_format"]

tot = 0
_hosts_stats = {}
top_key = nil
top_value = 0
num = 0
for key, value in pairs(hosts_stats) do
   host_info = hostkey2hostinfo(key);
   
   value = hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]

   if(value ~= nil) then 
      if(host_info["host"] == "255.255.255.255") then
	 key = "Broadcast"
      end
      _hosts_stats[value] = key -- ntop.getResolvedName(key)
      if((top_value < value) or (top_key == nil)) then
	 top_key = key
	 top_value = value
      end
      tot = tot + value
   end
end

-- Print up to this number of entries
max_num_entries = 10

-- Print entries whose value >= 5% of the total
threshold = (tot * 5) / 100

print "[\n"
num = 0
accumulate = 0
for key, value in pairsByKeys(_hosts_stats, rev) do
   if(key < threshold) then
      break
   end

   if(num > 0) then
      print ",\n"
   end

   if((ajax_format == nil) or (ajax_format == "d3")) then
      print("\t { \"label\": \"" .. value .."\", \"value\": ".. key ..", \"url\": \""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(value).."\" }")
   else
      print("\t [ \"" .. value .."\", ".. key .." ]")
   end	

   accumulate = accumulate + key
   num = num + 1

   if(num == max_num_entries) then
      break
   end
end

if((num == 0) and (top_key ~= nil)) then
   if((ajax_format == nil) or (ajax_format == "d3")) then
     print("\t { \"label\": \"" .. top_key .."\", \"value\": ".. top_value ..", \"url\": \""..ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(top_key).."\" }")
   else      
    print("\t [ \"" .. top_key .."\", ".. top_value .." ]")
   end

   accumulate = accumulate + top_value
end

-- In case there is some leftover do print it as "Other"
if(accumulate < tot) then
   if((ajax_format == nil) or (ajax_format == "d3")) then
      print(",\n\t { \"label\": \"Other\", \"value\": ".. (tot-accumulate) .." }")
   else
      print(",\n\t [ \"Other\", ".. (tot-accumulate) .." ]")
   end
end

print "\n]"




