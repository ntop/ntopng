--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Get local stats distribution for an interface
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/localstats.lua?ifid=1&iflocalstat_mode=distribution"
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v1/get/interface/localstats.lua?ifid=1"
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
end

interface.select(ifid)
local ifstats = interface.getStats()

if _GET["iflocalstat_mode"] == "distribution" then
   if ifstats["localstats"]["bytes"] == 0 then
      res[#res + 1] = { label = "No traffic yet", value = 0 }
   else
      local eth = ifstats["eth"]
      local sum = eth.IPv4_packets + eth.IPv6_packets + eth.ARP_packets + eth.MPLS_packets + eth.other_packets
      local five = 0.05 * sum
      local tot = 0

      local proto_list = {
         { label = "IPv4", value = eth.IPv4_packets },
         { label = "IPv6", value = eth.IPv6_packets },
         { label = "ARP",  value = eth.ARP_packets  },
         { label = "MPLS", value = eth.MPLS_packets },
      }

      for _, entry in ipairs(proto_list) do
         if entry.value > five then
            res[#res + 1] = { label = entry.label, value = entry.value }
            tot = tot + entry.value
         end
      end

      local leftover = sum - tot
      if leftover > 0 then
         res[#res + 1] = { label = "Other", value = leftover }
      end
   end
else
   local bytes = ifstats["localstats"]["bytes"]
   local sum = bytes["local2remote"] + bytes["local2local"] + bytes["remote2local"] + bytes["remote2remote"]

   if sum == 0 then
      res[#res + 1] = { label = "No traffic yet", value = 0 }
   else
      local five = 0.05 * sum
      local other = 0

      local traffic_list = {
         { label = "Local->Remote",  key = "local2remote"  },
         { label = "Local->Local",   key = "local2local"   },
         { label = "Remote->Local",  key = "remote2local"  },
         { label = "Remote->Remote", key = "remote2remote" },
      }

      for _, entry in ipairs(traffic_list) do
         local val = bytes[entry.key]
         if val > five then
            res[#res + 1] = { label = entry.label, value = val }
         else
            other = other + val
         end
      end

      if other > 0 then
         res[#res + 1] = { label = "Other", value = other }
      end
   end
end

rest_utils.answer(rc, res)