--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local pods_filter_s = _GET["custom_hosts"]

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

local pods_filter = nil
local totalRows = 0
local pods = interface.getPodsStats()
local sort_to_key = {}

if not isEmptyString(pods_filter_s) then
  pods_filter = swapKeysValues(split(pods_filter_s, ","))
end

for pod_name, pod in pairs(pods) do
  if((pods_filter == nil) or (pods_filter[pod_name] ~= nil)) then
    sort_to_key[pod_name] = pod_name
  end

  totalRows = totalRows + 1
end

-- ################################################


local res = {}
local i = 0
local ifId = getInterfaceId(ifname)

for key in pairsByValues(sort_to_key, sOrder) do
  if i >= to_skip + perPage then
    break
  end

  if (i >= to_skip) then
    local pod = pods[key]

   local column_info = "<a href='"
      ..ntop.getHttpPrefix().."/lua/flows_stats.lua?pod="..key.."'>"
      .."<span class='badge bg-info'>"..i18n("flows").."</span>"
      .."</a>"
   local chart = "-"

   if areContainersTimeseriesEnabled(ifId) then
      chart = '<a href="'.. ntop.getHttpPrefix() ..'/lua/pod_details.lua?pod='.. key ..'&page=historical"><i class="fas fa-chart-area fa-lg"></i></a>'
   end

   local num_containers = pod["num_containers"]
   if num_containers > 0 then
      num_containers = '<a href="'.. ntop.getHttpPrefix() ..'/lua/containers_stats.lua?pod='..key..'">' .. pod["num_containers"] .. '</a>'
   end

    res[#res + 1] = {
      column_info = column_info,
      column_pod = key,
      column_chart = chart,
      column_num_containers = num_containers,
      column_num_flows_as_client = pod["num_flows.as_client"],
      column_num_flows_as_server = pod["num_flows.as_server"],
      column_avg_rtt_as_client = format_utils.formatMillis(pod["rtt_as_client"]),
      column_avg_rtt_as_server = format_utils.formatMillis(pod["rtt_as_server"]),
      column_avg_rtt_variance_as_client = format_utils.formatMillis(pod["rtt_variance_as_client"]),
      column_avg_rtt_variance_as_server = format_utils.formatMillis(pod["rtt_variance_as_server"]),
    }
  end

  i = i + 1
end

-- ################################################

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = totalRows
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
