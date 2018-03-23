--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "mac_utils"
local host_pools_utils = require("host_pools_utils")
local json = require("dkjson")
sendHTTPContentTypeHeader('text/html')

interface.select(ifname)
local ifstats = interface.getStats()

-- Table parameters
local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local vlan         = _GET["vlan"]
local devices_mode = _GET["unassigned_devices"]

local sortPrefs = "unknown_devices"

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

if(isEmptyString(vlan)) then vlan = 0 end
if(sortOrder == "desc") then sOrder = false else sOrder = true end

local total_rows = 0
local mac_to_device = {}
local mac_to_sort = {}
local now = os.time()
local res = {}

local sortField
if sortColumn == "column_first_seen" then
   sortField = "seen.first"
elseif sortColumn == "column_last_seen" then
   sortField = "seen.last"
elseif sortColumn == "column_name" then
   sortField = "name"
elseif sortColumn == "column_mac" then
   sortField = "mac"
else
   -- sort in memory MACs first, off memory after
   sortField = "in_memory_mac"
   sortOrder = "desc"
end

-- First data source: memory
-- NB: we must fetch this data even if mode is "inactive_only", to properly filter redis data
local macs_stats = interface.getMacsInfo(nil, nil, nil, nil,
         true --[[ sourceMacsOnly ]], nil--[[manufacturer]],
	 tonumber(host_pools_utils.DEFAULT_POOL_ID), false)

if (macs_stats ~= nil) then
   macs_stats = macs_stats.macs

   for key, device in pairs(macs_stats) do
      device.in_memory_mac = "1" .. device["mac"]
      mac_to_device[device["mac"]] = device

      if sortField == "name" then
         mac_to_device[device["mac"]]["name"] = getDeviceName(device["mac"])
      end

      mac_to_sort[device["mac"]] = device[sortField]
      if devices_mode ~= "inactive_only" then
         total_rows = total_rows + 1
      end
   end
else
   macs_stats = {}
end

macs_stats = nil

-- Second data source: redis
if devices_mode ~= "active_only" then
   local keys = ntop.getKeysCache("ntopng.serialized_macs.ifid_"..(ifstats.id).."__*")

   for key in pairs(keys or {}) do
      local device = json.decode(ntop.getCache(key))

      if (device ~= nil) and (not mac_to_device[device["mac"]]) and (tostring(interface.findMacPool(device["mac"]) or 0) == host_pools_utils.DEFAULT_POOL_ID) then
         device.in_memory_mac = "0" .. device["mac"]
         mac_to_device[device["mac"]] = device

         if sortField == "name" then
            mac_to_device[device["mac"]]["name"] = getDeviceName(device["mac"])
         end

         mac_to_sort[device["mac"]] = device[sortField]
         total_rows = total_rows + 1
      end
   end
end

-- Visualize data
local i = 0
local num = 0

local sort_function
if sortOrder == "asc" then
   sort_function = asc
else
   sort_function = rev
end

for mac, _ in pairsByValues(mac_to_sort, sort_function) do
   i = i + 1

   local device = mac_to_device[mac]
   local in_memory = (device["manufacturer"] ~= nil)
   local filter_out = ((not in_memory) and devices_mode == "active_only") or (in_memory and devices_mode == "inactive_only")

   if (i > to_skip) and (not filter_out) then
      local record = {}

      if in_memory then
         record["column_mac"] = mac2link(device)
      else
         record["column_mac"] = macAddIcon(device["mac"])
      end

      record["key"] = device["mac"]
      record["column_name"] = device["name"] or getDeviceName(device["mac"])
      record["column_first_seen"] =  formatEpoch(device["seen.first"]) .. " [" .. secondsToTime(now - device["seen.first"]) .. " " .. i18n("details.ago").."]"
      record["column_last_seen"] = formatEpoch(device["seen.last"]) .. " [" .. secondsToTime(now - device["seen.last"]) .. " " .. i18n("details.ago").."]"
      -- record["manufacturer"] = device["manufacturer"] or ntop.getMacManufacturer(device["mac"])

      res[#res + 1] = record

      num = num + 1
      if num >= perPage then
         break
      end
   end
end

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total_rows
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result, nil))
