--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Get packet size or IP version distribution for an interface
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/interface/pkt_distribution.lua?ifid=1&distr=size
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/interface/pkt_distribution.lua?ifid=1&distr=ipver
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local distr_type = _GET["distr"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)
local ifstats = interface.getStats()

if (distr_type == nil) or (distr_type == "size") then
   local what = ifstats["pktSizeDistribution"]["size"]

   local pkt_distribution = {
      ['upTo64']   = '<= 64',
      ['upTo128']  = '64 <= 128',
      ['upTo256']  = '128 <= 256',
      ['upTo512']  = '256 <= 512',
      ['upTo1024'] = '512 <= 1024',
      ['upTo1518'] = '1024 <= 1518',
      ['upTo2500'] = '1518 <= 2500',
      ['upTo6500'] = '2500 <= 6500',
      ['upTo9000'] = '6500 <= 9000',
      ['above9000']= '> 9000'
   }

   local tot = 0
   for _, value in pairs(what) do
      tot = tot + value
   end

   local threshold = (tot * 5) / 100
   local sum = 0

   for key, value in pairs(what) do
      if value > threshold and pkt_distribution[key] ~= nil then
         res[#res + 1] = { label = pkt_distribution[key], value = value }
         sum = sum + value
      end
   end

   if sum < tot then
      res[#res + 1] = { label = "Other", value = (tot - sum) }
   end

elseif distr_type == "ipver" then
   res[#res + 1] = { label = "IPv6", value = ifstats.eth.IPv6_packets }
   res[#res + 1] = { label = "IPv4", value = ifstats.eth.IPv4_packets }

else
   rc = rest_utils.consts.err.invalid_args
   rest_utils.answer(rc)
   return
end

rest_utils.answer(rc, res)