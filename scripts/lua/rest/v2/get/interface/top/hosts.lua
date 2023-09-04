--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local stats_utils = require("stats_utils")
local graph_utils = require "graph_utils"

--
-- Get interface top hosts
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interface/top/hosts.lua
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local new_charts = toboolean(_GET["new_charts"])

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local hosts_stats = interface.getHostsInfo(false, "column_traffic")
hosts_stats = hosts_stats["hosts"]

local tot = 0
local _hosts_stats = {}
local top_key = nil
local top_value = 0
local num = 0
for key, value in pairs(hosts_stats) do
   local host_info = hostkey2hostinfo(key);

   local value = hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]

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
local max_num_entries = 10

-- Print entries whose value >= 5% of the total
local threshold = (tot * 5) / 100

local res = {}

num = 0
local accumulate = 0
for key, value in pairsByKeys(_hosts_stats, rev) do
   if(key < threshold) then
      break
   end

   res[#res+1] = {
      label = value,
      value = key, 
      url = ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(value)
   }

   accumulate = accumulate + key
   num = num + 1

   if(num == max_num_entries) then
      break
   end
end

if((num == 0) and (top_key ~= nil)) then
   res[#res+1] = {
      label = top_key,
      value = top_value, 
      url = ntop.getHttpPrefix().."/lua/host_details.lua?"..hostinfo2url(top_key)
   }
   accumulate = accumulate + top_value
end

-- In case there is some leftover do print it as "Other"
if(accumulate < tot) then
   res[#res+1] = {
      label = "Other",
      value = (tot-accumulate), 
      url = "#"
   }
end

local js_formatter = "bytesToSize"
rest_utils.answer(rc, graph_utils.convert_pie_data(res, new_charts, js_formatter))
