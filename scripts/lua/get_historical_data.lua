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

local res = {["status"] = "unable to parse the request, please check input parameters."}
local res_by_key = {}
if stats_type == "top_talkers" then
   if not peer1 and not peer2 then
      -- compute the top-talkers for the selected time interval
      res = require("top_scripts.top_talkers").getHistoricalTopInInterval(ifid, ifname, epoch_start + 60, epoch_end + 60, add_vlan)

      for _, record in pairs(res) do
	 record["label"] = ntop.getResolvedAddress(record["addr"])
	 res_by_key[record["addr"]] = record
      end
   else
      res = getHostTopTalkers(ifid, peer1, nil, epoch_start + 60, epoch_end + 60)

      for _, record in pairs(res) do
	 record["label"] = ntop.getResolvedAddress(record["addr"])
	 res_by_key[record["addr"]] = record
      end
      -- tprint(res)
   end
elseif stats_type =="top_applications" then

   res = getTopApplications(ifid, peer1, peer2, nil, epoch_start + 60, epoch_end + 60)

   -- add protocol labels
   for _, record in pairs(res) do
      record["label"] = getApplicationLabel(interface.getnDPIProtoName(tonumber(record["application"])))
      res_by_key[record["application"]] = record
   end
   -- tprint(res)
elseif stats_type =="peers_traffic_histogram" and peer1 and peer2 then
   res = getPeersTrafficHistogram(ifid, peer1, peer2, nil, epoch_start + 60, epoch_end + 60)

   for _, record in pairs(res) do
      record["peer1_label"] = ntop.getResolvedAddress(record["peer1_addr"])
      record["peer2_label"] = ntop.getResolvedAddress(record["peer2_addr"])
      res_by_key[record["peer1_addr"]..record["peer2_addr"]] = record

   end
   -- tprint(res)
end

-- sort the result based on received parameters
local sorter = {}
for record_key, record in pairs(res_by_key) do
   -- TODO: fix for double peers
   if sort_column == "column_label" then sorter[record_key] = record["label"]
   elseif sort_column == "column_address" then sorter[record_key] = record["address"]
   elseif sort_column == "column_bytes" then sorter[record_key] = tonumber(record["bytes"])
   elseif sort_column == "column_tot_bytes" then sorter[record_key] = tonumber(record["tot_bytes"])
   elseif sort_column == "column_packets" then sorter[record_key] = tonumber(record["packets"])
   elseif sort_column == "column_tot_packets" then sorter[record_key] = tonumber(record["tot_packets"])
   elseif sort_column == "column_flows" then sorter[record_key] = tonumber(record["flows"])
   elseif sort_column == "column_tot_flows" then sorter[record_key] = tonumber(record["tot_flows"])
   else sorter[record_key] = record["label"] end
   -- protect possible nils in sorting values
   if sorter[record_key] == nil then sorter[record_key] = 0 end
end

-- make res_by_key compliant with column_ notation
-- also add hyperlinks, bytes format, etc.
for record_key, record in pairs(res_by_key) do
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
      record_contents["column_packets"] = pktsToSize(tonumber(record["packets"]))
   elseif record["tot_packets"] then
      record_contents["column_packets"] = pktsToSize(tonumber(record["tot_packets"]))
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
   res_by_key[record_key] = record_contents
end

local num_page = 0
local total_rows = 0
local result_data = {}
for record_key,_ in pairsByValues(sorter, funct) do
   if to_skip > 0 then
      to_skip = to_skip - 1
   elseif num_page < per_page then
      table.insert(result_data, res_by_key[record_key])
      num_page = num_page + 1
   end
   total_rows = total_rows + 1
end
-- tprint(res_by_key)
local result = {}
result["perPage"] = per_page
result["currentPage"] = current_page
result["totalRows"] = total_rows
result["data"] = result_data
result["sort"] = {{sort_column, sort_order}}

print(json.encode(result, nil))
