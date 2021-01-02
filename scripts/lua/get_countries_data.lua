--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

require("country_utils")
sendHTTPContentTypeHeader('text/html')

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local sortPrefs = "country"

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

to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end

local country_stats = interface.getCountriesInfo({sortColumn = sortColumn,
					  maxHits = perPage, toSkip = to_skip,
					  a2zSortOrder = sOrder, detailsLevel = "higher"})

local total_rows = 0

if(country_stats ~= nil) then
   total_rows = country_stats["numCountries"]
   country_stats = country_stats["Countries"]
end

local res_formatted = {}
local now = os.time()
local ifId = getInterfaceId(ifname)

for _, country in ipairs(country_stats) do
   res_formatted[#res_formatted + 1] = country2record(ifId, country)
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total_rows
result["data"] = res_formatted
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result, nil))
