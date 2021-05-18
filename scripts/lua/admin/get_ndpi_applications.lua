--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local protos_utils = require("protos_utils")
local page_utils = require("page_utils")

local json = require("dkjson")
sendHTTPContentTypeHeader('text/html')


-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local proto_filter = _GET["l7proto"]
local category_filter = _GET["category"]

local sortPrefs = "ndpi_application_category"
local custom_protos = protos_utils.parseProtosTxt()
local proto_to_num_rules = {}
local applications = interface.getnDPIProtocols()

for proto, rules in pairs(custom_protos) do
   proto_to_num_rules[proto] = #rules
end

local function makeApplicationHostsList(appname)
   local hosts_list = {}

   for _, rule in ipairs(custom_protos[appname] or {}) do
      hosts_list[#hosts_list + 1] = rule.value
   end

   return table.concat(hosts_list, ",")
end

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

if category_filter ~= nil and starts(category_filter, "cat_") then
   category_filter = split(category_filter, "cat_")[2]
end

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = rev_insensitive else sOrder = asc_insensitive end

local sorter = {}
local num_apps = 0
for app_name, app_id in pairs(applications) do
   if app_name == "Unknown" then
      -- prevent the Unknown protocol from being re-assigned
      -- nDPI bug?
      goto continue
   end

   local cat = ntop.getnDPIProtoCategory(tonumber(app_id))

   if not isEmptyString(proto_filter) then
     if tostring(app_id) ~= proto_filter then
       goto continue
     end
   end

   if not isEmptyString(category_filter) then
      if tostring(cat.id) ~= category_filter then
       goto continue
      end
   end

   applications[app_name] = {app_name = app_name, app_id = app_id, cat = cat}
   num_apps = num_apps + 1

   if sortColumn == "column_" or sortColumn == "column_ndpi_application" then
      sorter[app_name] = app_name
   elseif sortColumn == "column_ndpi_application_category" then
      sorter[app_name] = cat["name"]
   elseif sortColumn == "column_num_hosts" then
      sorter[app_name] = proto_to_num_rules[app_name] or 0
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
   record["column_num_hosts"] = proto_to_num_rules[app["app_name"]] or 0
   record["column_application_hosts"] = makeApplicationHostsList(app["app_name"])
   record["column_is_custom"] = ntop.isCustomApplication(tonumber(app["app_id"]))

   cat_select_dropdown = '<select class="form-select" style="width:320px;" name="proto_' .. app["app_id"] .. '">'
   local current_id = tostring(app["cat"]["id"])

   for cat_name, cat_id in pairsByKeys(categories, asc_insensitive) do
      cat_select_dropdown = cat_select_dropdown .. [[<option value="cat_]] ..cat_id .. [["]] ..
         ternary(cat_id == current_id, " selected", "") .. [[>]] ..
         getCategoryLabel(cat_name) .. [[</option>]]
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
