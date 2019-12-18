--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local ts_utils = require("ts_utils")
local rtt_utils = require("rtt_utils")
local plugins_utils = require("plugins_utils")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local currentPage   = _GET["currentPage"]
local perPage       = _GET["perPage"]
local sortColumn    = _GET["sortColumn"]
local sortOrder     = _GET["sortOrder"]
local cont_filter_s = _GET["custom_hosts"]
local rtt_host      = _GET["rtt_host"]

local sortPrefs = "rtt_hosts"

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

local rtt_hosts = rtt_utils.getHosts()
local totalRows = 0
local sort_to_key = {}

if rtt_host then
   if rtt_hosts[rtt_host] then
      sort_to_key[rtt_host] = rtt_hosts[rtt_host]["host"]
      totalRows = 1
   end
else
   for key, config in pairs(rtt_hosts) do
      sort_to_key[key] = config.host

      totalRows = totalRows + 1
   end
end

 --################################################

local res = {}
local i = 0

for key in pairsByValues(sort_to_key, sOrder) do
  if i >= to_skip + perPage then
    break
  end

  if (i >= to_skip) then
    local rtt_host = rtt_hosts[key]
    local chart = ""

    if ts_utils.exists("monitored_host:rtt", {ifid=getSystemInterfaceId(), host=key}) then
      chart = '<a href="'.. plugins_utils.getUrl('rtt_stats.lua') .. '?rtt_host='.. key ..'&page=historical"><i class="fas fa-chart-area fa-lg"></i></a>'
    end

    local column_last_ip = ""
    local column_last_update = ""
    local column_last_rtt = ""
    local last_update = rtt_utils.getLastRttUpdate(key)

    if(last_update ~= nil) then
      local tdiff = os.time() - last_update.when

      if(tdiff <= 600) then
        column_last_update  = secondsToTime(tdiff).. " " ..i18n("details.ago")
      else
        column_last_update = format_utils.formatPastEpochShort(last_update.when)
      end

      column_last_rtt = last_update.value .. " ms"
      column_last_ip = last_update.ip
    end
 
    res[#res + 1] = {
      column_key = key,
      column_host = rtt_host.host,
      column_chart = chart,
      column_iptype = rtt_host.iptype,
      column_max_rrt = rtt_host.max_rtt,
      column_last_rrt = column_last_rtt,
      column_last_update = column_last_update,
      column_last_ip = column_last_ip,
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
