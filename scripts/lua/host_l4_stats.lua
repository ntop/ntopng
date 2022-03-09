--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read list of active hosts
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.1", "vlan": "1"}' http://localhost:3000/lua/rest/v2/get/host/active.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local rsp = {}

interface.select(ifname)

host_info = url2hostinfo(_GET)
host = interface.getHostInfo(host_info["host"],host_info["vlan"])

if(host == nil) then
   print("\t[ ]\n")
else
   tot = 0
   _ifstats = {}

   tot = 0
   for id, _ in ipairs(l4_keys) do
      label = l4_keys[id][1]
      key = l4_keys[id][2]
      traffic = 0
      if(host[key..".bytes.sent"] ~= nil) then traffic = traffic + host[key..".bytes.sent"] end
      if(host[key..".bytes.rcvd"] ~= nil) then traffic = traffic + host[key..".bytes.rcvd"] end

      _ifstats[traffic] = label
      tot = tot + traffic
   end

   -- Print up to this number of entries
   max_num_entries = 5

   -- Print entries whose value >= 5% of the total
   threshold = (tot * 3) / 100

   print "[\n"
   num = 0
   accumulate = 0
   for key, value in pairsByKeys(_ifstats, rev) do
      if(key < threshold) then
	 break
      end

      if(num > 0) then
	 print ",\n"
      end

      print("\t { \"label\": \"" .. value .."\", \"value\": ".. key .." }")
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
