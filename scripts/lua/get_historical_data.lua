--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "top_talkers"
require "db_utils"
local json = require ("dkjson")

sendHTTPHeader('text/html; charset=iso-8859-1')

ifid = getInterfaceId(ifname)

-- query parameters
local epoch_start = _GET["epoch_start"]
local epoch_end = _GET["epoch_end"]

-- use this two params to see statistics of a single host
-- or for a pair of them
local peer1 = _GET["peer1"]
local peer2 = _GET["peer2"]
if peer2 and not peer1 then
	peer1 = peer2
	peer2 = nil
end

local host_info = url2hostinfo(_GET)
local host = nil
if host_info["host"] then
   host = interface.getHostInfo(host_info["host"],host_info["vlan"])
end


-- specify the type of stats
local stats_type = _GET["stats_type"]
if stats_type == nil or (stats_type ~= "top_talkers" and stats_type ~= "top_applications" and stats_type ~= "peers_traffic_histogram") then
	-- default to top traffic
	stats_type = "top_talkers"
end

-- datatable parameters
local current_page = _GET["currentPage"]
local per_page     = _GET["perPage"]
local sort_column  = _GET["sortColumn"]
local sort_order   = _GET["sortOrder"]
local total_rows   = _GET["totalRows"]

if not sort_column or sort_column == "" then
   sort_column = getDefaultTableSort("historical_stats_"..stats_type)
else
   if sort_column ~= "column_" then
      tablePreferences("sort_historical_stats_"..stats_type, sort_column)
   end
end

tablePreferences("sort_order_historical_stats_"..stats_type,sort_order)
--[[
if not sort_order or sort_order == "" then
   sort_order = getDefaultTableSortOrder("historical_stats_"..stats_type)
   io.write('got by default '..sort_order..'\n')
else
   tablePreferences("sort_order_historical_stats_"..stats_type,sort_order)
end
]]

if sort_order == "asc" then
   funct = asc
else
   funct = rev
end

if current_page == nil then
   current_page = 1
else
   current_page = tonumber(current_page)
end

if per_page == nil then
   per_page = getDefaultTableSize()
else
   per_page = tonumber(per_page)
   tablePreferences("rows_number", per_page)
end
local to_skip = (current_page - 1) * per_page
if to_skip < 0 then to_skip = 0 end

-- prepare queries offset an limit depending on
-- received values. A received value total_rows = -1 (or total_rows == nil)
-- means that the interface doesn't know the number of rows
-- and thus it is up to this script to compute it, and
-- send it back to the caller

if total_rows == nil or tonumber(total_rows) == nil then
   total_rows = -1
else
   total_rows = tonumber(total_rows)
end

-- default: 100 rows starting from offset 0
local offset = 0
local limit = 100
if total_rows ~= -1 then
   offset = to_skip
   limit = per_page
end

-- start building the response
local res = {["status"] = "unable to parse the request, please check input parameters."}
if stats_type == "top_talkers" then
   if not peer1 and not peer2 then
      -- compute the top-talkers for the selected time interval
      res = require("top_scripts.top_talkers").getHistoricalTopInInterval(ifid, ifname, epoch_start + 60, epoch_end + 60, add_vlan)

      for _, record in pairs(res) do
	 record["label"] = ntop.getResolvedAddress(record["addr"])
      end
   else
      res = getHostTopTalkers(ifid, peer1, nil, epoch_start + 60, epoch_end + 60)

      for _, record in pairs(res) do
	 record["label"] = ntop.getResolvedAddress(record["addr"])
      end
      -- tprint(res)
   end
elseif stats_type =="top_applications" then
   res = getTopApplications(ifid, peer1, peer2, nil, epoch_start + 60, epoch_end + 60, sort_column, sort_order, offset, limit)

   -- add protocol labels
   for _, record in pairs(res) do
      record["label"] = getApplicationLabel(interface.getnDPIProtoName(tonumber(record["application"])))
   end
   -- tprint(res)
elseif stats_type =="peers_traffic_histogram" and peer1 and peer2 then
   res = getPeersTrafficHistogram(ifid, peer1, peer2, nil, epoch_start + 60, epoch_end + 60)

   for _, record in pairs(res) do
      record["peer1_label"] = ntop.getResolvedAddress(record["peer1_addr"])
      record["peer2_label"] = ntop.getResolvedAddress(record["peer2_addr"])
   end
   -- tprint(res)
end

-- slice the result if the interface didn't know the total_rows
local res_sliced = {}
if total_rows ~= -1 then
   -- nothing to slice here, query has already sliced the result
   res_sliced = res
else --  i.e., total_rows == -1, that it, it was unknown
   -- slice the first page of the results
   -- and update total_rows
   local cur = 0
   for _, record in pairs(res) do
      if cur < per_page then
	 table.insert(res_sliced, record)
      end
      cur = cur + 1
   end
   total_rows = cur
end

-- make res_formatted compliant with column_ notation
-- also add hyperlinks, bytes format, etc.
local res_formatted = {}
for _, record in pairs(res_sliced) do
   local record_contents = {}
   if not record["label"] or record["label"] == "" then record["label"] = record["addr"] end
   record_contents["column_label"] = record["label"]
   record_contents["column_addr"] = record["addr"]
   -- 'normalize' possible different names, e.g., group bytes or tot_bytes in bytes
   -- and rename fields with the 'column_' prefix that is conventionally used in the interface
   if record["bytes"] then
      record_contents["column_bytes"] = bytesToSize(tonumber(record["bytes"]))
   elseif record["tot_bytes"] then
      record_contents["column_bytes"] = bytesToSize(tonumber(record["tot_bytes"]))
   else
      record_contents["column_bytes"] = "n.a."
   end
   if record["packets"] then
      record_contents["column_packets"] = formatValue(tonumber(record["packets"]))
   elseif record["tot_packets"] then
      record_contents["column_packets"] = formatValue(tonumber(record["tot_packets"]))
   else
      record_contents["column_packets"] = "n.a."
   end
   if record["flows"] then
      record_contents["column_flows"] = formatValue(tonumber(record["flows"]))
   elseif record["tot_flows"] then
      record_contents["column_flows"] = formatValue(tonumber(record["tot_flows"]))
   else
      record_contents["column_flows"] = "n.a."
   end
   table.insert(res_formatted, record_contents)
end

-- tprint(res_formatted)
-- tprint(res)
local result = {}
result["perPage"] = per_page
result["currentPage"] = current_page
result["totalRows"] = total_rows
result["data"] = res_formatted
result["sort"] = {{sort_column, sort_order}}

print(json.encode(result, nil))
