--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

local pod_filter = _GET["pod"]

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local cont_filter_s = _GET["custom_hosts"]

local sortPrefs = "containers_data"

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

local containers_filter = nil
local totalRows = 0
local containers = interface.getContainersStats(pod_filter)
local sort_to_key = {}

if not isEmptyString(cont_filter_s) then
  containers_filter = swapKeysValues(split(cont_filter_s, ","))
end

for container_name, container in pairs(containers) do
  if((containers_filter == nil) or (containers_filter[container_name] ~= nil)) then
     sort_to_key[container_name] = container_name
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
    local container = containers[key]

   local column_info = "<a href='"
      ..ntop.getHttpPrefix().."/lua/flows_stats.lua?container="..key.."'>"
      .."<span class='badge bg-info'>"..i18n("flows").."</span>"
      .."</a>"
   local chart = "-"

   if areContainersTimeseriesEnabled(ifId) then
      chart = '<a href="'.. ntop.getHttpPrefix() ..'/lua/container_details.lua?container='.. key ..'&page=historical"><i class="fas fa-chart-area fa-lg"></i></a>'
   end
 
    res[#res + 1] = {
      column_info = column_info,
      column_key = key,
      column_chart = chart,
      column_container = format_utils.formatContainer(container.info),
      column_num_flows_as_client = container["num_flows.as_client"],
      column_num_flows_as_server = container["num_flows.as_server"],
      column_avg_rtt_as_client = format_utils.formatMillis(container["rtt_as_client"]),
      column_avg_rtt_as_server = format_utils.formatMillis(container["rtt_as_server"]),
      column_avg_rtt_variance_as_client = format_utils.formatMillis(container["rtt_variance_as_client"]),
      column_avg_rtt_variance_as_server = format_utils.formatMillis(container["rtt_variance_as_server"]),
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
