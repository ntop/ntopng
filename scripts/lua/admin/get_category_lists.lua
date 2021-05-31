--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require("dkjson")
local lists_utils = require("lists_utils")
local format_utils = require("format_utils")

local category_filter = _GET["category"]
local lists = lists_utils.getCategoryLists()
local now = os.time()

sendHTTPContentTypeHeader('application/json')

-- ################################################

local function getListStatusLabel(list)
  if not list.enabled then
    return '<span class="badge bg-danger">'.. i18n("nedge.status_disabled") ..'</span>'
  end

  if list.status.last_error then
    local info = ""
    local info_msg = ""

    if type(list.status.last_error) == "string" then
      info = ' <i class="fas fa-info-circle"></i>'
      info_msg = list.status.last_error
    end

    return '<span title="'.. info_msg ..'" class="badge bg-danger">'.. i18n("error") .. info ..'</span>'
  end

  return '<span class="badge bg-success">'.. i18n("category_lists.enabled") ..'</span>'
end

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local enabledStatus  = _GET["enabled_status"]

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
  local catname = interface.getnDPICategoryName(list.category)

  if((not isEmptyString(category_filter)) and (category_filter ~= catname)) then
    goto continue
  end

  if enabledStatus == "disabled" and list.enabled then
    goto continue
  elseif enabledStatus == "enabled" and not list.enabled then
    goto continue
  end

  totalRows = totalRows + 1

  list.category_name = catname
  list.name = list_name
  list.status_label = getListStatusLabel(list)

  if sortColumn == "column_category_name" then
    sort_to_key[list_name] = getCategoryLabel(list.category_name)
  elseif sortColumn == "column_last_update" then
    sort_to_key[list_name] = list.status.last_update
  elseif sortColumn == "column_num_hosts" then
    sort_to_key[list_name] = list.status.num_hosts
  elseif sortColumn == "column_status" then
    sort_to_key[list_name] = list.status_label
  elseif sortColumn == "column_update_interval_label" then
    sort_to_key[list_name] = list.update_interval
  else
    -- default
    sort_to_key[list_name] = list_name
  end

  ::continue::
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
    local update_interval_label = ''
    if list.update_interval == 86400 then
       update_interval_label = i18n("alerts_thresholds_config.daily")
    elseif list.update_interval == 3600 then
       update_interval_label = i18n("alerts_thresholds_config.hourly")
    elseif list.update_interval == 0 then
       update_interval_label = i18n("alerts_thresholds_config.manual")
    end

    res[#res + 1] = {
      column_name = list.name,
      column_label = list.name .. ' <a href="'.. list.url ..'" target="_blank"><i class="fas fa-external-link-alt"></i></a>',
      column_status = list.status_label,
      column_url = list.url,
      column_enabled = list.enabled,
      column_update_interval = list.update_interval,
      column_update_interval_label = update_interval_label,
      column_category = "cat_" .. list.category,
      column_category_name = getCategoryLabel(list.category_name),
      column_num_hosts = ternary(list.status.num_hosts > 0, format_utils.formatValue(list.status.num_hosts), ''),
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
