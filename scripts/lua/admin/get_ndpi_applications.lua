--
-- (C) 2013-17 - ntop.org
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

if(sortOrder == "desc") then sOrder = rev else sOrder = asc end

local applications = interface.getnDPIProtocols()

local sorter = {}
local num_apps = 0
for app_name, app_id in pairs(applications) do
   if app_name == "Unknown" then
      goto continue -- prevent the Unknown category from being re-assigned
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

local res_formatted = {}

local cur_num = 0
for app, _ in pairsByValues(sorter, sOrder) do
   app = applications[app]

   cur_num = cur_num + 1
   if cur_num <= to_skip then
      goto continue
   elseif cur_num > to_skip + perPage then
      break
   end

   local record = {}
   record["column_ndpi_application_id"] = app["app_id"]
   record["column_ndpi_application_category_id"] = app["cat"]["id"]
   record["column_ndpi_application"] = app["app_name"]
   record["column_ndpi_application_category"] = app["cat"]["name"]

   --local record = as2record(as)
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
