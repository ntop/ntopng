--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require("dkjson")
local categories_utils = require("categories_utils")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


-- ################################################
-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local category_filter = _GET["l7proto"]

-- ################################################
--  Sorting and Pagination

local sortPrefs = "custom_categories_hosts"

if((sortColumn == nil) or (sortColumn == "column_"))then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs,sortColumn)
   end
end

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder(sortPrefs)
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_order_"..sortPrefs,sortOrder)
   end
end

if currentPage == nil then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if perPage == nil then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number", perPage)
end

-- ################################################

interface.select(ifname)
local ifid = getInterfaceId(ifname)

local to_skip = (currentPage-1) * perPage

if sortOrder == "desc" then sOrder = rev_insensitive else sOrder = asc_insensitive end

local items = {}
local sorter = {}
local num_items = 0

local items = interface.getnDPICategories()

for item_name, item_id in pairs(items) do
   if not isEmptyString(category_filter) and (category_filter ~= item_id) then
      goto continue
   end

   local hosts_list = categories_utils.getCustomCategoryHosts(item_id)
   local num_hosts = #hosts_list
   local num_protocols = table.len(interface.getnDPIProtocols(tonumber(item_id)))

   items[item_name] = { name = item_name, id = item_id, num_hosts = num_hosts, hosts_list = hosts_list , num_protocols = num_protocols }
   num_items = num_items + 1

   if sortColumn == "column_" or sortColumn == "column_category_name" then
      sorter[item_name] = getCategoryLabel(item_name)
   elseif sortColumn == "column_num_hosts" then
      sorter[item_name] = num_hosts
   elseif sortColumn == "column_num_protos" then
      sorter[item_name] = num_protocols
   end

   ::continue::
end

local res_formatted = {}
local cur_num = 0
for sorted_item, _ in pairsByValues(sorter, sOrder) do
   cur_num = cur_num + 1
   if cur_num <= to_skip then
      goto continue
   elseif cur_num > to_skip + perPage then
      break
   end

   local record = {}

   record["column_category_id"] = tostring(items[sorted_item]["id"])
   record["column_category_name"] = getCategoryLabel(items[sorted_item]["name"])
   record["column_num_hosts"] = tostring(items[sorted_item].num_hosts)
   record["column_num_protos"] = string.format('<a href="%s/lua/admin/edit_categories?tab=protocols&category=cat_%u">%s</a>', ntop.getHttpPrefix(), items[sorted_item]["id"], tostring(items[sorted_item].num_protocols))
   record["column_category_hosts"] = table.concat(items[sorted_item].hosts_list, ",")

   res_formatted[#res_formatted + 1] = record
   ::continue::
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = num_items
result["data"] = res_formatted
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result, nil))
