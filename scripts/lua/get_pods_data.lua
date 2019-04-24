--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local sortPrefs = "pods_data"

-- ################################################

if isEmptyString(sortColumn) or sortColumn == "column_" then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs, sortColumn)
   end
end

if isEmptyString(_GET["sortColumn"]) then
  sortOrder = getDefaultTableSortOrder(sortPrefs, true)
end

if((_GET["sortColumn"] ~= "column_")
  and (_GET["sortColumn"] ~= "")) then
    tablePreferences("sort_order_"..sortPrefs, sortOrder, true)
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

local sOrder = ternary(sortOrder == "desc", rev_insensitive, asc_insensitive)
local to_skip = (currentPage-1) * perPage

-- ################################################

local function formatLatency(x)
   if(x < 0.1) then return 0 end
   return string.format("%.1f ms", x)
end

local totalRows = 0
local pods = interface.getPodsStats()
local sort_to_key = {}

for pod_name, pod in pairs(pods) do
  sort_to_key[pod_name] = pod_name

  totalRows = totalRows + 1
end

-- ################################################


local res = {}
local i = 0

for key in pairsByValues(sort_to_key, sOrder) do
  if i >= to_skip + perPage then
    break
  end

  if (i >= to_skip) then
    local pod = pods[key]

    res[#res + 1] = {
      column_pod = '<a href="'.. ntop.getHttpPrefix() ..'/lua/containers_stats.lua?pod='..key..'">' .. key .. '</a>',
      column_num_containers = pod["num_containers"],
      column_num_flows_as_client = pod["num_flows.as_client"],
      column_num_flows_as_server = pod["num_flows.as_server"],
      column_avg_rtt_as_client = formatLatency(pod["rtt_as_client"]),
      column_avg_rtt_as_server = formatLatency(pod["rtt_as_server"]),
      column_avg_rtt_variance_as_client = formatLatency(pod["rtt_variance_as_client"]),
      column_avg_rtt_variance_as_server = formatLatency(pod["rtt_variance_as_server"]),
    }
  end
end

-- ################################################

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = totalRows
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
