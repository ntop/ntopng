--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"

local presets_utils = require "presets_utils"
local json = require("dkjson")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


if not isAdministrator() then
   return
end

-- ################################################
-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local device_type = _GET["device_type"]
local policy_filter = _GET["policy_filter"]
local proto_filter = _GET["l7proto"]
local category = _GET["category"]

interface.select(ifname)

presets_utils.init()

-- ################################################
--  Sorting and Pagination

local sortPrefs = "nf_device_protocols"

if isEmptyString(sortColumn) or sortColumn == "column_" then
   sortColumn = getDefaultTableSort(sortPrefs)
elseif sortColumn ~= "" then
   tablePreferences("sort_"..sortPrefs, sortColumn)
end

if isEmptyString(_GET["sortColumn"]) then
   sortOrder = getDefaultTableSortOrder(sortPrefs, true)
end

if _GET["sortColumn"] ~= "column_" and _GET["sortColumn"] ~= "" then
   tablePreferences("sort_order_"..sortPrefs, sortOrder, true)
end

if currentPage == nil then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if perPage == nil then
   perPage = 10
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number_policies", perPage)
end

-- ################################################

local to_skip = (currentPage-1) * perPage

if sortOrder == "desc" then sOrder = rev_insensitive else sOrder = asc_insensitive end

local device_policies = presets_utils.getDevicePolicies(device_type)

local function matchesPolicyFilter(item_id)
   if isEmptyString(policy_filter) then
      return true
   end

   local policy = device_policies[tonumber(item_id)]
   if policy == nil then
      if policy_filter ~= presets_utils.DEFAULT_ACTION then -- != default
         return false
      end
   elseif policy.clientActionId ~= nil and policy_filter ~= policy.clientActionId and
          policy.serverActionId ~= nil and policy_filter ~= policy.serverActionId then
      return false
   end

   return true
end

local function matchesProtoFilter(item_id)
   if isEmptyString(proto_filter) then
      return true
   end

   return proto_filter == item_id
end

local function matchesCategoryFilter(item_id)
   if isEmptyString(category) then
      return true
   end

   local cat = ntop.getnDPIProtoCategory(tonumber(item_id))
   return category == cat.name
end

local items = {}
local sorter = {}
local num_items = 0

items = interface.getnDPIProtocols(nil, true)

for item_name, item_id in pairs(items) do
   if not matchesProtoFilter(item_id) or not matchesPolicyFilter(item_id) or not matchesCategoryFilter(item_id) then
      goto continue
   end

   local cat = ntop.getnDPIProtoCategory(tonumber(item_id))

   items[item_name] = { name = item_name, id = item_id, conf = device_policies[tonumber(item_id)], catName = cat.name }
   num_items = num_items + 1

   if sortColumn == "column_" or sortColumn == "column_ndpi_application" then
      sorter[item_name] = item_name
   elseif sortColumn == "column_ndpi_category" then
      sorter[item_name] = cat.name
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

   record["column_ndpi_application_id"] = tostring(items[sorted_item]["id"])
   record["column_ndpi_application"] = tostring(items[sorted_item]["name"])
   record["column_ndpi_category"] = items[sorted_item].catName

   local cr = ''
   local sr = ''
   local conf = items[sorted_item]["conf"]
   local field_id = items[sorted_item]["id"]
   for _, action in ipairs(presets_utils.actions) do
      local checked = ''
      if ((conf == nil or conf.clientActionId == nil) and action.id == presets_utils.DEFAULT_ACTION) or
          ((conf ~= nil and conf.clientActionId ~= nil) and conf.clientActionId == action.id) then
         checked = 'checked'
      end
      cr = cr..'<label class="radio-inline mx-2"><input type="radio" name="'..field_id..'_client_action" value="'..action.id..'" '..checked..'><span class="mx-1" style="font-size: 16px;">'..action.icon..'</span></label>'

      checked = ''
      if ((conf == nil or conf.serverActionId == nil) and action.id == presets_utils.DEFAULT_ACTION) or
          ((conf ~= nil and conf.serverActionId ~= nil) and conf.serverActionId == action.id) then
         checked = 'checked'
      end
      sr = sr..'<label class="radio-inline mx-2"><input type="radio" name="'..field_id..'_server_action" value="'..action.id..'" '..checked..'><span class="mx-1" style="font-size: 16px;">'..action.icon..'</span></label>'
   end

   record["column_client_policy"] = cr
   record["column_server_policy"] = sr

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
