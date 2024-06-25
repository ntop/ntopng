--
-- (C) 2013-24 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local callback_utils = require "callback_utils"
local rest_utils = require("rest_utils")
local json = require("dkjson")

require "label_utils"
require "ntop_utils"
require "http_lint"
require("country_utils")

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

-- stats table for each country
local country_stats = interface.getCountriesInfo({sortColumn = sortColumn,
					  maxHits = perPage, toSkip = to_skip,
					  a2zSortOrder = sOrder, detailsLevel = "higher"})

local total_rows = 0

if(country_stats ~= nil) then
   total_rows = country_stats["numCountries"]
   country_stats = country_stats["Countries"]
end

-- checks if country timeseries is enabled for the current interface
local charts_enabled = areCountryTimeseriesEnabled(interface.getId())

if (charts_enabled == true) then
   charts_enabled = 1
else
   charts_enabled = 0
end

local rsp = {}

for key, value in pairs(country_stats) do
   local record = {} 
   
   local bytes_sent = value["bytes.sent"]
   local bytes_rcvd = value["bytes.rcvd"]

   record["name"] = value["country"]
   record["hosts"] = value["num_hosts"]
   record["seen_since"] = value["seen.first"]
   record["score"] = value["score"]
   
   record["breakdown"] = { 
      bytes_sent = bytes_sent, 
      bytes_rcvd = bytes_rcvd 
   }

   record["throughput"] = value["throughput_bps"]
   record["traffic"] = bytes_sent + bytes_rcvd
   record["charts_enabled"] = charts_enabled
   
   -- add record to response
   table.insert(rsp, record)

end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total_rows
result["data"] = res_formatted
result["sort"] = {{sortColumn, sortOrder}}

rest_utils.answer(rest_utils.consts.success.ok, rsp)
