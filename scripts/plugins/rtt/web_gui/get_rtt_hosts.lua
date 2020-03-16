--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
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
local charts_available = plugins_utils.timeseriesCreationEnabled()

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
      if sortColumn == "column_iptype" then
         sort_to_key[key] = config.iptype
      elseif sortColumn == "column_probetype" then
         sort_to_key[key] = config.probetype
      elseif sortColumn == "column_max_rrt" then
         sort_to_key[key] = config.max_rtt
      elseif sortColumn == "column_last_ip" then
         local last_ip = rtt_utils.getLastRttUpdate(key)

         if last_ip and last_ip.ip then
            last_ip = last_ip.ip
         else
            last_ip = ""
         end

         sort_to_key[key] = last_ip
         sOrder = ternary(sortOrder == "desc", ip_address_rev, ip_address_asc)
      elseif sortColumn == "column_last_rrt" then
         local last_rtt = rtt_utils.getLastRttUpdate(key)

         if last_rtt and last_rtt.when then
            last_rtt = tonumber(last_rtt.value) or 0
         else
            last_rtt = 0
         end

         sort_to_key[key] = last_rtt
      elseif sortColumn == "column_last_update" then
         local last_update = rtt_utils.getLastRttUpdate(key)

         if last_update and last_update.when then
            last_update = tonumber(last_update.value) or 0
         else
            last_update = 0
         end

         sort_to_key[key] = last_update
      else
         -- Sort by key instead of host to keep proper sort order in
         -- case both ipv4 and ipv6 are used
         sort_to_key[key] = key
      end

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

    if charts_available then
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
      column_host = unescapeHttpHost(rtt_host.host),
      column_chart = chart,
      column_probetype = rtt_host.probetype,
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
