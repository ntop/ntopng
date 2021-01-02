--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local internals_utils = require "internals_utils"

sendHTTPContentTypeHeader('application/json')

-- ################################################

local iffilter         = _GET["iffilter"]
local hash_table       = _GET["hash_table"]
local currentPage      = _GET["currentPage"]
local perPage          = _GET["perPage"]
local sortColumn       = _GET["sortColumn"]
local sortOrder        = _GET["sortOrder"]

local sortPrefs = "internals_hash_tables_data"

-- ################################################

local function hash_table_utilization(htstats)
   local active_entries = htstats.stats.hash_entry_states.hash_entry_state_active
   local idle_entries = htstats.stats.hash_entry_states.hash_entry_state_idle
   local active_vs_max = round(active_entries  / htstats.stats.max_hash_size * 100, 2)
   local idle_vs_max = round(idle_entries /  htstats.stats.max_hash_size * 100, 2)
   local free = 100 - active_vs_max - idle_vs_max

   return {active_vs_max = active_vs_max, idle_vs_max = idle_vs_max, free = free}
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

local ifaces_ht_stats = {}

for _, iface in pairs(interface.getIfNames()) do
   if iffilter and iffilter ~= tostring(getInterfaceId(iface)) then
      goto continue
   end

   interface.select(iface)
   local ht_stats = interface.getHashTablesStats()

   -- Flatten out the nested tables
   for ht, stats in pairs(ht_stats) do
      ifaces_ht_stats["ifid_"..getInterfaceId(iface).."_"..ht] = {iface = iface, ifid = getInterfaceId(iface), ht = ht, stats = stats}
   end

   ::continue::
end

local totalRows = 0
local sort_to_key = {}

for k, htstats in pairs(ifaces_ht_stats) do
   local stats = htstats.stats

   if hash_table then
      if htstats.ht ~= hash_table then
	 goto continue
      end
   end

   if(sortColumn == "column_idle_entries") then
      sort_to_key[k] = stats.hash_entry_states.hash_entry_state_idle
   elseif(sortColumn == "column_active_entries") then
      sort_to_key[k] = stats.hash_entry_states.hash_entry_state_active
   elseif(sortColumn == "column_hash_table_utilization") then
      local utiliz = hash_table_utilization(htstats)
      sort_to_key[k] = -utiliz["free"]
   elseif(sortColumn == "column_hash_table_name") then
      sort_to_key[k] = i18n("hash_table."..htstats.ht)
   elseif(sortColumn == "column_name") then
      sort_to_key[k] = getHumanReadableInterfaceName(getInterfaceName(htstats.ifid))
   else
      sort_to_key[k] = htstats.ifid
   end

   totalRows = totalRows + 1

   ::continue::
end

-- ################################################

local res = {}
local i = 0

for key, _ in pairsByValues(sort_to_key, sOrder) do
   if i >= to_skip + perPage then
      break
   end

   if i >= to_skip then
      local record = {}
      local htstats = ifaces_ht_stats[key]

      local active_entries = htstats.stats.hash_entry_states.hash_entry_state_active
      local idle_entries = htstats.stats.hash_entry_states.hash_entry_state_idle

      if not htstats.ht then
	 htstats.ht = "Unknown"
      end
      local htlabel = i18n("hash_table."..htstats.ht) or htstats.ht

      local warn = ""
      local idle_perc = idle_entries * 100 / (idle_entries + active_entries + 1)

      if(idle_perc >= 50) then
         warn = "<i class=\"fas fa-exclamation-triangle\" title=\"".. i18n("internals.high_idle_entries") .."\"></i> "
      end

      record["column_key"] = key
      record["column_ifid"] = string.format("%i", htstats.ifid)
      record["column_active_entries"] = ternary(active_entries > 0, format_utils.formatValue(active_entries), '')
      record["column_idle_entries"] = ternary(idle_entries > 0, format_utils.formatValue(idle_entries), '')

      record["column_name"] = string.format('<a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=%i&page=internals&tab=hash_tables">%s</a>', htstats.ifid, getHumanReadableInterfaceName(getInterfaceName(htstats.ifid)))
      record["column_hash_table_name"] = warn .. htlabel

      if iffilter then
	 if areInternalTimeseriesEnabled(iffilter) then
	    record["column_chart"] = '<A HREF=\"'..ntop.getHttpPrefix()..'/lua/hash_table_details.lua?hash_table='..htstats.ht..'\"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
	 end
      end

      record["column_hash_table_utilization"] = ''
      if active_entries > 0 or idle_entries > 0 then
	 local utiliz = hash_table_utilization(htstats)

	 record["column_hash_table_utilization"] = internals_utils.getHashTablesFillBar(utiliz["active_vs_max"], utiliz["idle_vs_max"], utiliz["free"])
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
