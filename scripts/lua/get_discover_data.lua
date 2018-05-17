--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local discover = require "discover_utils"

sendHTTPContentTypeHeader('text/html')

-- Table parameters
local currentPage = _GET["currentPage"]
local perPage     = _GET["perPage"]
local sortColumn  = _GET["sortColumn"]
local sortOrder   = _GET["sortOrder"]

local os_filter = tonumber(_GET["operating_system"])
local devtype_filter = tonumber(_GET["device_type"])
local manuf_filter = _GET["manufacturer"]

local sortPrefs = "discovery_sort_col"

-- ################################################

local doa_ox_fd = nil
local doa_ox = nil

local enable_doa_ox = false

if(enable_doa_ox) then
   local doa_ox = require "doa_ox"
   doa_ox_fd = doa_ox.init("/tmp/doa_ox.update")
end

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
   perPage = 10
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number_discovery", perPage)
end

-- ################################################

interface.select(ifname)

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = rev_insensitive else sOrder = asc_insensitive end

local res = {data={}}

local discovered = discover.discover2table(ifname)

-- ################################################

if(enable_doa_ox) then
  doa_ox.header(doa_ox_fd)
end

local sort_2_field = {
  column_name = "name",
  column_manufacturer = "manufacturer",
  column_os = "os",
  column_info = "info",
  column_device = "device_type",
}

local sorted = {}
local sort_field = "mac"

if sort_2_field[sortColumn] then
  sort_field = sort_2_field[sortColumn]
end

local tot_rows = 0
discovered["devices"] = discovered["devices"] or {}

for el_idx, el in pairs(discovered["devices"]) do
  -- Manufacturer
  local manufacturer = ""
  if el["manufacturer"] then
    manufacturer = el["manufacturer"]
  else
    manufacturer = get_manufacturer_mac(el["mac"])
  end

  local actual_manuf = manufacturer

  if el["modelName"] then
    manufacturer = manufacturer .. " ["..el["modelName"].."]"
  end
  el.manufacturer = manufacturer

  -- Name
  local name = ""
  if el["sym"] then name = name .. el["sym"] end

  if el["symIP"] then
    if el["sym"] then
      name = name .. " ["..el["symIP"].."]"
    else
      name = el["symIP"]
    end
  end
  el.name = name

  -- Operating System
  local device_os = ""

  if el.os_type == nil then
    local mac_info = interface.getMacInfo(el.mac)

    if(mac_info ~= nil) then
      el.os_type = mac_info.operatingSystem
    end
  end

  el.os = getOperatingSystemIcon(el.os_type)

  -- Device info
  local devinfo = ""
  if el["information"] then devinfo = devinfo .. table.concat(el["information"], "<br>") end
  if el["url"] then
    if el["information"] then
      devinfo = devinfo .. "<br>"..el["url"]
    else
      devinfo = devinfo .. el["url"]
    end
  end
  el.info = devinfo

  if(enable_doa_ox) then
    if el.os then
      el.operatingSystem = getOperatingSystemName(el.os)
    end

    doa_ox.device2OX(doa_ox_fd, el)
  end

  -- Filter
  if (os_filter ~= nil) and (el.os_type ~= os_filter) then
    goto continue
  end
  if (manuf_filter ~= nil) and (actual_manuf ~= manuf_filter) then
    goto continue
  end

  if (devtype_filter ~= nil) and (discover.devtype2id(el.device_type) ~= devtype_filter) then
    goto continue
  end

  sorted[el_idx] = el[sort_field]
  tot_rows = tot_rows + 1

  ::continue::
end

if(enable_doa_ox) then
  doa_ox.term(doa_ox_fd)
end

-- ################################################

local cur_num = 0

-- Sort
for idx, _ in pairsByValues(sorted, sOrder) do
  el = discovered["devices"][idx]

  cur_num = cur_num + 1
  if cur_num <= to_skip then
    goto continue
  elseif cur_num > to_skip + perPage then
    break
  end

  local rec = {}

  rec.column_ip = [[<a href="]] ..ntop.getHttpPrefix().. [[/lua/host_details.lua?host=]]
    ..tostring(el["ip"]).. [[">]] ..tostring(el["ip"]).. [[</a>]]
    ..ternary(el["icon"], "&nbsp;" ..(el["icon"] or "").. "&nbsp;", "")
    ..ternary(el["ghost"], " <font color=red>" ..(discover.ghost_icon or "").. "</font>", "")

  rec.column_mac = [[<a href="]] ..ntop.getHttpPrefix().. [[/lua/mac_details.lua?host=]] ..el["mac"].. [[">]] ..el["mac"].. [[</a>]]
  rec.column_name = el.name
  rec.column_info = el.info
  rec.column_device = el["device_label"]
  rec.column_manufacturer = el.manufacturer
  rec.column_os = el.os

  res.data[#res.data + 1] = rec
  ::continue::
end

res["perPage"] = perPage
res["currentPage"] = currentPage
res["totalRows"] = tot_rows

res["sort"] = {{sortColumn, sortOrder}}
print(json.encode(res))
