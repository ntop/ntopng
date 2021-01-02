--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local json = require("dkjson")
local dhcp_utils = require("dhcp_utils")
require "lua_utils"

local ifid = _GET["ifid"]

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]
local sortPrefs = "dhcp_ranges"

sendHTTPContentTypeHeader('application/json')

if((ifid == nil) or (not isAdministrator())) then
  return
end

interface.select(getInterfaceName(ifid))

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

local sOrder
local to_skip = (currentPage-1) * perPage

if((sortColumn == "column_first_ip") or (sortColumn == "column_last_ip")) then
  sOrder = ternary(sortOrder == "desc", ip_address_rev, ip_address_asc)
else
  sOrder = ternary(sortOrder == "desc", rev_insensitive, asc_insensitive)
end

-- ################################################

local ranges = dhcp_utils.listRanges(ifid)

local totalRows = 0
local sort_to_key = {}

for key, range in pairs(ranges) do
  totalRows = totalRows + 1

  if sortColumn == "column_first_ip" then
    sort_to_key[key] = range[1]
  elseif sortColumn == "column_last_ip" then
    sort_to_key[key] = range[2]
  else
    -- default
    sort_to_key[key] = key
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
    local range = ranges[key]

    res[#res + 1] = {
      column_first_ip = range[1],
      column_last_ip = range[2],
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
