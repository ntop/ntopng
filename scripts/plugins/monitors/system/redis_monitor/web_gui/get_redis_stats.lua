--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local plugins_utils = require("plugins_utils")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local cmd_ids_filter = _GET["custom_hosts"]

local sortPrefs = "redis_commands_data"

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

local sOrder = ternary(sortOrder == "asc", asc_insensitive, rev_insensitive)
local to_skip = (currentPage-1) * perPage

-- ################################################

if(cmd_ids_filter) then
  cmd_ids_filter = swapKeysValues(string.split(cmd_ids_filter, ",") or {cmd_ids_filter})
end

local commands_stats = ntop.getCacheStats() or {}
local totalRows = 0
local sort_to_key = {}

for command, hits in pairs(commands_stats) do
  if(cmd_ids_filter and (cmd_ids_filter[command] == nil)) then
    goto continue
  end
 
  if(sortColumn == "column_command") then
    sort_to_key[command] = command
  else
    sort_to_key[command] = hits
  end

  totalRows = totalRows + 1
  ::continue::
end

-- ################################################

local res = {}
local i = 0
local sys_ifaceid = getSystemInterfaceId()
local charts_available = plugins_utils.timeseriesCreationEnabled()

for key in pairsByValues(sort_to_key, sOrder) do
  if i >= to_skip + perPage then
    break
  end

  if (i >= to_skip) then
    local chart = ""
    local value = commands_stats[key]

    if(charts_available) then
      chart = '<a href="?page=historical&redis_command='..key..'&ts_schema=redis:hits"><i class=\'fas fa-chart-area fa-lg\'></i></a>'
    end

    res[#res + 1] = {
      column_key = key,
      column_command = string.upper(string.sub(key, 5)),
      column_chart = chart,
      column_hits = value,
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
