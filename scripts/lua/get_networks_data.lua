--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "network_utils"

local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local sortPrefs = "local_network"

if((sortColumn == nil) or (sortColumn == "column_"))then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs,sortColumn)
   end
end

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder(sortPrefs)
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_order_"..sortPrefs,sortOrder)
   end
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number", perPage)
end

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end

local networks_stats = interface.getNetworksStats()
local total_rows = 0

local sort_helper = {}
for n, ns in pairs(networks_stats) do
   total_rows = total_rows + 1

   if sortColumn == "column_hosts" then
      sort_helper[n] = ns["num_hosts"]
   elseif sortColumn == "column_thpt" then
      sort_helper[n] = ns["throughput_bps"]
   elseif sortColumn == "column_traffic" then
      sort_helper[n] = ns["bytes.sent"] + ns["bytes.rcvd"]
   else
      sort_helper[n] = getLocalNetworkAlias(ns["network_key"])
   end
end

local res_formatted = {}
local cur_row = 0
local tot_row_in_page = 0

for n, _ in pairsByValues(sort_helper, ternary(sOrder, asc, rev)) do
   cur_row = cur_row + 1

   if cur_row <= to_skip then
      goto continue
   end

   local record = network2record(interface.getId(), networks_stats[n])
   res_formatted[#res_formatted + 1] = record

   tot_row_in_page = tot_row_in_page + 1

   if tot_row_in_page >= perPage then
      break
   end

   ::continue::
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total_rows
result["data"] = res_formatted
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result, nil))
