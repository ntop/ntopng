--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local host_pools = require "host_pools"
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local sortPrefs = "pool_id"

-- Instantiate host pools
local host_pools_instance = host_pools:create()

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

local ifid = interface.getId()
local pools_stats = interface.getHostPoolsStats()
local total_rows = 0

local sort_helper = {}
for pool_id, pool_stats in pairs(pools_stats) do
   total_rows = total_rows + 1

   if sortColumn == "column_hosts" then
      sort_helper[pool_id] = pool_stats["num_hosts"]
   elseif sortColumn == "column_thpt" then
      sort_helper[pool_id] = pool_stats["throughput_bps"]
   elseif sortColumn == "column_traffic" then
      sort_helper[pool_id] = pool_stats["bytes.sent"] + pool_stats["bytes.rcvd"]
   else
      sort_helper[pool_id] = host_pools_instance:get_pool_name(pool_id)
   end
end

local res_formatted = {}
local cur_row = 0

for n, _ in pairsByValues(sort_helper, ternary(sOrder, asc, rev)) do
   cur_row = cur_row + 1

   if cur_row <= to_skip then
      goto continue
   end

   local record = host_pools_instance:hostpool2record(ifid, n, pools_stats[n])
   res_formatted[#res_formatted + 1] = record

   if cur_row >= perPage then
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
