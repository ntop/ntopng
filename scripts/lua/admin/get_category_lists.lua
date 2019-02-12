--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require("dkjson")
local lists_utils = require("lists_utils")
local format_utils = require("format_utils")

local lists = lists_utils.getCategoryLists()
local now = os.time()

sendHTTPContentTypeHeader('application/json')

-- ################################################

local function getListStatusLabel(list)
  if not list.enabled then
    return '<span class="label label-default">'.. i18n("nedge.status_disabled") ..'</span>'
  end

  if list.status.last_error then
    return '<span class="label label-danger">'.. i18n("error") ..'</span>'
  end

  if lists_utils.shouldUpdate(list.name, list, now) then
    return '<span class="label label-info">'.. i18n("category_lists.ready_for_update") ..'</span>'
  end

  return '<span class="label label-success">'.. i18n("category_lists.enabled") ..'</span>'
end

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local sortPrefs = "category_lists"

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

local totalRows = 0
local sort_to_key = {}

for list_name, list in pairs(lists) do
  totalRows = totalRows + 1

  list.category_name = interface.getnDPICategoryName(list.category)
  list.name = list_name
  list.status_label = getListStatusLabel(list)

  if sortColumn == "column_category_name" then
    sort_to_key[list_name] = list.category_name
  elseif sortColumn == "column_last_update" then
    sort_to_key[list_name] = list.status.last_update
  elseif sortColumn == "column_num_hosts" then
    sort_to_key[list_name] = list.status.num_hosts
  elseif sortColumn == "column_status" then
    sort_to_key[list_name] = list.status_label
  else
    -- default
    sort_to_key[list_name] = list_name
  end
end

-- ################################################

local res = {}
local i = 0

for key in pairsByValues(sort_to_key, sOrder) do
  if i >= to_skip + perPage then
    break
  end

  if (i >= to_skip) then
    local list = lists[key]

    res[#res + 1] = {
      column_name = list.name,
      column_label = list.name .. ' <a href="'.. list.url ..'" target="_blank"><i class="fa fa-external-link"></i></a>',
      column_status = list.status_label,
      column_url = list.url,
      column_enabled = list.enabled,
      column_update_interval = list.update_interval,
      column_category = "cat_" .. list.category,
      column_category_name = list.category_name,
      column_num_hosts = list.status.num_hosts,
      column_last_update = format_utils.formatPastEpochShort(list.status.last_update),
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
