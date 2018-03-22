--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")
sendHTTPContentTypeHeader('text/html')

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local proto_filter = _GET["l7proto"]

local sortPrefs = "ndpi_application_category"

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

interface.select(ifname)

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = rev_insensitive else sOrder = asc_insensitive end

local applications = interface.getnDPIProtocols()

local sorter = {}
local num_apps = 0
for app_name, app_id in pairs(applications) do
   if app_name == "Unknown" then
      -- prevent the Unknown protocol from being re-assigned
      -- nDPI bug?
      goto continue
   end

   local cat = interface.getnDPIProtoCategory(tonumber(app_id))

   applications[app_name] = {app_name = app_name, app_id = app_id, cat = cat}
   num_apps = num_apps + 1

   if sortColumn == "column_" or sortColumn == "column_ndpi_application" then
      sorter[app_name] = app_name
   elseif sortColumn == "column_ndpi_application_category" then
      sorter[app_name] = cat["name"]
   end

   ::continue::
end

local categories = interface.getnDPICategories()

local res_formatted = {}

if not isEmptyString(proto_filter) then
   num_apps = 1
end

local cur_num = 0
for app, _ in pairsByValues(sorter, sOrder) do
   app = applications[app]

   if not isEmptyString(proto_filter) then
     if tostring(app["app_id"]) ~= proto_filter then
       goto continue
     end
   end

   cur_num = cur_num + 1
   if cur_num <= to_skip then
      goto continue
   elseif cur_num > to_skip + perPage then
      break
   end

   local record = {}
   record["column_ndpi_application_id"] = tostring(app["app_id"])
   record["column_ndpi_application_category_id"] = tostring(app["cat"]["id"])
   record["column_ndpi_application"] = app["app_name"]

   cat_select_dropdown = '<select class="form-control" style="width:320px;" name="proto_' .. app["app_id"] .. '">'
   local current_id = tostring(app["cat"]["id"])
   
   for cat_name, cat_id in pairsByKeys(categories, asc_insensitive) do
      cat_select_dropdown = cat_select_dropdown .. [[<option value="cat_]] ..cat_id .. [["]] ..
         ternary(cat_id == current_id, " selected", "") .. [[>]] ..
         cat_name .. [[</option>]]
   end
   cat_select_dropdown = cat_select_dropdown .. "</select>"

   record["column_ndpi_application_category"] = cat_select_dropdown

   res_formatted[#res_formatted + 1] = record
   ::continue::
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = num_apps
result["data"] = res_formatted
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result, nil))
