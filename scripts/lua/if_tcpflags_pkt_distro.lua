--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local stats_utils = require("stats_utils")

sendHTTPContentTypeHeader('text/html')

local host_info = url2hostinfo(_GET)
local ifid = _GET["ifid"]
local what = {}

interface.select(ifid)

local pkt_distribution = {
   ['syn'] = 'SYN',
   ['synack'] = 'SYN/ACK',
   ['finack'] = 'FIN/ACK',
   ['rst'] = 'RST',
}

if(host_info["host"] ~= nil) then
   local stats = interface.getHostInfo(host_info["host"],host_info["vlan"])
   if stats == nil then return end

   -- join sent and rcvd
   local sent_stats = stats["pktStats.sent"]["tcp_flags"]
   local rcvd_stats = stats["pktStats.recv"]["tcp_flags"]

   for k, _ in pairs(sent_stats) do
      what[k] = sent_stats[k] + rcvd_stats[k]
   end
else
   local stats = interface.getStats()
   if stats == nil then return end

   what = stats["pktSizeDistribution"]["tcp_flags"]
end

local res = {}
for key, value in pairs(what) do
   if value > 0 then
      res[#res + 1] = {label = pkt_distribution[key], value = value}
   end
end

if table.len(res) == 0 then
   res[#res + 1] = {label = "Other", value = 100}
else
   res = stats_utils.collapse_stats(res, 1, 1 --[[ threshold ]])
end

print(json.encode(res))
