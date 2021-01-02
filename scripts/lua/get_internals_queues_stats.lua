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
local currentPage      = _GET["currentPage"]
local perPage          = _GET["perPage"]
local sortColumn       = _GET["sortColumn"]
local sortOrder        = _GET["sortOrder"]

local sortPrefs = "internals_queues_data"

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

local ifaces_queues_stats = {}

for _, iface in pairs(interface.getIfNames()) do
   if iffilter and iffilter ~= tostring(getInterfaceId(iface)) and iffilter ~= getSystemInterfaceId() then
      goto continue
   end

   interface.select(iface)
   local queues_stats = interface.getQueuesStats()

   -- Flatten out the nested tables
   for queue, stats in pairs(queues_stats) do
      ifaces_queues_stats["ifid_"..getInterfaceId(iface).."_"..queue] = {iface = iface, ifid = getInterfaceId(iface), queue = queue, stats = stats}
   end

   ::continue::
end

local totalRows = 0
local sort_to_key = {}

for k, queuestats in pairs(ifaces_queues_stats) do
   local stats = queuestats.stats

   if hash_table then
      if queuestats.queue ~= hash_table then
	 goto continue
      end
   end

   if(sortColumn == "column_num_failed_enqueues") then
      sort_to_key[k] = stats.num_failed_enqueues
   elseif(sortColumn == "column_name") then
      sort_to_key[k] = getHumanReadableInterfaceName(getInterfaceName(queuestats.ifid))
   elseif(sortColumn == "column_queue_name") then
      sort_to_key[k] = i18n("queue."..queuestats.queue) or queuestats.queue
   else
      sort_to_key[k] = queuestats.ifid
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
      local queuestats = ifaces_queues_stats[key]

      local queuelabel = i18n("queue."..queuestats.queue) or queuestats.queue
      local queuedescr = i18n("queue_description."..queuestats.queue) or ""

      if not isEmptyString(queuedescr) then
	 queuedescr = ' <i class="fas fa-info-circle fa-sm" title="'.. queuedescr ..'"></i>'
      else
	 queuedescr = ""
      end

      record["column_key"] = key
      record["column_ifid"] = string.format("%i", queuestats.ifid)
      record["column_num_failed_enqueues"] = ternary(queuestats.stats.num_failed_enqueues > 0, format_utils.formatValue(queuestats.stats.num_failed_enqueues), '')
      record["column_name"] = getHumanReadableInterfaceName(getInterfaceName(queuestats.ifid))

      local queue_name = string.format("<span id='%s' title='%s'>%s</span>", key, queuedescr, queuelabel)
      record["column_queue_name"] = queue_name

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
