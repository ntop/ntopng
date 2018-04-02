--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "mac_utils"
local json = require("dkjson")
sendHTTPContentTypeHeader('text/html')

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local vlan          = _GET["vlan"]
local devices_mode  = _GET["devices_mode"]
local manufacturer  = _GET["manufacturer"]
local device_type   = tonumber(_GET["device_type"])

local sortPrefs = "macs"

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

local source_macs_only = false
local dhcp_macs_only = false

if devices_mode == "source_macs_only" then   
   source_macs_only = true   
elseif devices_mode == "dhcp_macs_only" then
   dhcp_macs_only = true   
end

interface.select(ifname)

to_skip = (currentPage-1) * perPage

if(isEmptyString(vlan)) then vlan = 0 end
if(sortOrder == "desc") then sOrder = false else sOrder = true end

local macs_stats = interface.getMacsInfo(sortColumn, perPage, to_skip, sOrder,
					 source_macs_only, manufacturer,
					 nil, device_type, "", dhcp_macs_only)

local total_rows = 0

if(macs_stats ~= nil) then
   total_rows = macs_stats["numMacs"]
end
macs_stats = macs_stats["macs"]

local res_formatted = {}
for _, mac in ipairs(macs_stats) do
   local record = mac2record(mac)
   table.insert(res_formatted, record)
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total_rows
result["data"] = res_formatted
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result, nil))
