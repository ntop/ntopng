--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)

host_info = url2hostinfo(_GET)
host = interface.getHostInfo(host_info["host"],host_info["vlan"])

if((host == nil) or (host["categories"] == nil)) then
   print("\t[ ]\n")
else
   cat = host["categories"]
   tot = 0
   _cat = {}
   for k,v in pairs(cat) do
      _cat[v] = k
      tot = tot + v
   end

   -- Print up to this number of entries
   max_num_entries = 5

   -- Print entries whose value >= 5% of the total
   threshold = (tot * 3) / 100

   print "[\n"
   num = 0
   accumulate = 0
   for key, value in pairsByKeys(_cat, rev) do
      if(key < threshold) then
	 break
      end

      if(num > 0) then
	 print ",\n"
      end

      print("\t { \"label\": \"" .. capitalize(getCategoryLabel(value)) .."\", \"value\": ".. key .." }")
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

   print "\n]"
end