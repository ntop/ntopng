--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local ts_utils = require "ts_utils"
local user_scripts = require "user_scripts"

sendHTTPContentTypeHeader('application/json')

-- ################################################

local iffilter           = _GET["iffilter"]
local user_script_target  = _GET["user_script_target"]
local currentPage        = _GET["currentPage"]
local perPage            = _GET["perPage"]
local sortColumn         = _GET["sortColumn"]
local sortOrder          = _GET["sortOrder"]

local sortPrefs = "internals_user_scripts_data"

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

local ifaces_user_scripts_stats = {}

local subdirs_list = user_scripts.listSubdirs()

for _, iface in pairs(interface.getIfNames()) do
   if iffilter and iffilter ~= tostring(getInterfaceId(iface)) then
      goto continue
   end

   for _, subdir in ipairs(subdirs_list) do
      local subdir_benchmarks = user_scripts.getLastBenchmark(getInterfaceId(iface), subdir["id"])

      for mod_k, mod_benchmarks in pairs(subdir_benchmarks) do
	 for hook_k, hook_benchmark in pairs(mod_benchmarks) do
	    local flat_k = string.format("%s_%s_%s_%s", getInterfaceId(iface), subdir["id"], mod_k, hook_k)

	    ifaces_user_scripts_stats[flat_k] = {
	       iface = iface, ifid = getInterfaceId(iface),
	       subdir = subdir["label"],
	       mod_k = mod_k,
	       hook_k = hook_k,
	       hook_benchmark = hook_benchmark}
	 end
      end

   end

   ::continue::
end

local totalRows = 0
local sort_to_key = {}

for k, user_script_stats in pairs(ifaces_user_scripts_stats) do
   if user_script_target then
      if user_script_stats.subdir ~= user_script_target then
	 goto continue
      end
   end

   if(sortColumn == "column_last_duration") then
      sort_to_key[k] = user_script_stats.hook_benchmark.tot_elapsed
   elseif(sortColumn == "column_last_num_calls") then
      sort_to_key[k] = user_script_stats.hook_benchmark.tot_num_calls
   elseif(sortColumn == "column_user_script_name") then
      sort_to_key[k] = user_script_stats.mod_k
   elseif(sortColumn == "column_user_script_target") then
      sort_to_key[k] = user_script_stats.subdir
   elseif(sortColumn == "column_hook") then
      sort_to_key[k] = user_script_stats.hook_k
   elseif(sortColumn == "column_name") then
      sort_to_key[k] = getHumanReadableInterfaceName(getInterfaceName(user_script_stats.ifid))
   else
      sort_to_key[k] = user_script_stats.subdir
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
      local script_stats = ifaces_user_scripts_stats[key]

      local last_duration = script_stats.hook_benchmark.tot_elapsed
      local last_num_calls = script_stats.hook_benchmark.tot_num_calls

      record["column_key"] = key
      record["column_ifid"] = string.format("%i", script_stats.ifid)

      record["column_last_duration"] = last_duration * 1000 -- expressed as milliseconds
      record["column_last_num_calls"] = last_num_calls

      record["column_name"] = string.format('<a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid=%i&page=internals&tab=user_scripts">%s</a>', script_stats.ifid, getHumanReadableInterfaceName(getInterfaceName(script_stats.ifid)))


      record["column_user_script_target"] = script_stats.subdir
      record["column_user_script_name"] = script_stats.mod_k
      record["column_hook"] = script_stats.hook_k

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
