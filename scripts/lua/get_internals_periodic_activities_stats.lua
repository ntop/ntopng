--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local ts_utils = require "ts_utils"
local internals_utils = require "internals_utils"

sendHTTPContentTypeHeader('application/json')

-- ################################################

local iffilter           = _GET["iffilter"]
local periodic_script  = _GET["periodic_script"]
local currentPage        = _GET["currentPage"]
local perPage            = _GET["perPage"]
local sortColumn         = _GET["sortColumn"]
local sortOrder          = _GET["sortOrder"]

local sortPrefs = "internals_periodic_activites_data"

-- ################################################

local function time_utilization(stats)
   local busy = stats.duration.last_duration_ms / stats.duration.max_duration_ms * 100

   return {busy = busy, available = 100 - busy}
end

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

local ifaces_scripts_stats = {}

for _, iface in pairs(interface.getIfNames()) do
   if iffilter and iffilter ~= tostring(getInterfaceId(iface)) then
      goto continue
   end

   interface.select(iface)
   local scripts_stats = interface.getPeriodicActivitiesStats()

   -- Flatten out the nested tables
   for script in pairs(internals_utils.periodic_scripts_durations) do
      local stats = scripts_stats[script] or {
	 duration = {
	    max_duration_ms = 0,
	    last_duration_ms = 0,
	 }
      }

      ifaces_scripts_stats[iface.."_"..script] = {iface = iface, ifid = getInterfaceId(iface), script = script, stats = stats}
   end

   ::continue::
end

local totalRows = 0
local sort_to_key = {}

for k, script_stats in pairs(ifaces_scripts_stats) do
   local stats = script_stats.stats

   if periodic_script then
      if script_stats.script ~= periodic_script then
	 goto continue
      end
   end

   stats.duration.max_duration_ms = internals_utils.periodic_scripts_durations[script_stats.script] * 1000
   stats.perc_duration = stats.duration.last_duration_ms * 100 / (stats.duration.max_duration_ms)
   
   if(sortColumn == "column_time_perc") then
      local utiliz = time_utilization(script_stats.stats)
      sort_to_key[k] = -utiliz["available"]
   elseif(sortColumn == "column_last_duration") then
      sort_to_key[k] = script_stats.stats.duration.last_duration_ms
   elseif(sortColumn == "column_periodic_activity_name") then
      sort_to_key[k] = script_stats.script
   elseif(sortColumn == "column_name") then
      sort_to_key[k] = getHumanReadableInterfaceName(getInterfaceName(script_stats.ifid))
   else
      sort_to_key[k] = script_stats.script
   end

   totalRows = totalRows + 1

   ::continue::
end

-- ################################################

local res = {}
local i = 0

for key in pairsByValues(sort_to_key, sOrder) do
   if i >= to_skip + perPage then
      break
   end

   if i >= to_skip then
      local record = {}
      local script_stats = ifaces_scripts_stats[key]

      local max_duration = script_stats.stats.duration.max_duration_ms
      local last_duration = script_stats.stats.duration.last_duration_ms
      local warn = ""

      if(last_duration > max_duration) then
         warn = "<i class=\"fas fa-exclamation-triangle fa-lg\" title=\"".. i18n("internals.script_deadline_exceeded") .."\" style=\"color: #f0ad4e;\"></i> "
      end

      record["column_key"] = key
      record["column_ifid"] = string.format("%i", script_stats.ifid)
      record["column_time_perc"] = script_stats.stats.perc_duration

      local utiliz = time_utilization(script_stats.stats)
      record["column_time_perc"] = internals_utils.getPeriodicActivitiesFillBar(utiliz["busy"], utiliz["available"])
      
      record["column_last_duration"] = last_duration

      record["column_name"] = string.format('<a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=%i&page=internals&tab=periodic_activities">%s</a>', script_stats.ifid, getHumanReadableInterfaceName(getInterfaceName(script_stats.ifid)))

      record["column_periodic_activity_name"] = warn .. script_stats.script

      if iffilter then
	 if ts_utils.exists("periodic_script:duration", {ifid = iffilter, periodic_script = script_stats.script}) then
	    record["column_chart"] = '<A HREF=\"'..ntop.getHttpPrefix()..'/lua/periodic_script_details.lua?periodic_script='..script_stats.script..'&ts_schema=periodic_script:duration\"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
	 end
      end

      res[#res + 1] = record
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
