--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local discover = require "discover_utils"
local rest_utils = require "rest_utils"

local os_filter = tonumber(_GET["operating_system"])
local devtype_filter = tonumber(_GET["device_type"])
local manuf_filter = _GET["manufacturer"]

-- ################################################

local doa_ox_fd = nil
local doa_ox = nil

local enable_doa_ox = false

if(enable_doa_ox) then
   local doa_ox = require "doa_ox"
   doa_ox_fd = doa_ox.init("/tmp/doa_ox.update")
end

-- ################################################

interface.select(ifname)

local res = {}

local discovered = discover.discover2table(ifname)

-- ################################################

if(enable_doa_ox) then
  doa_ox.header(doa_ox_fd)
end

discovered["devices"] = discovered["devices"] or {}

for _, el in pairs(discovered["devices"]) do
  -- Manufacturer
  local manufacturer = ""
  if el["manufacturer"] then
    manufacturer = el["manufacturer"]
  else
    manufacturer = get_manufacturer_mac(el["mac"])
  end

  local actual_manuf = manufacturer

  if(el["modelName"] and (el["modelName"] ~= "")) then
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

  -- Retrieve information from L3 host
  local host = interface.getHostInfo(el["ip"])

  if(host ~= nil) then
    el.os_type = host.os
  end

  el.os = discover.getOsIcon(el.os_type)

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
      el.operatingSystem = discover.getOsName(el.os)
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

  local rec = {}
  
  rec.column_ip = ip2detailshref(el["ip"], nil, nil, el["ip"])
    ..ternary(el["icon"], "&nbsp;" ..(el["icon"] or "").. "&nbsp;", "")
    ..ternary(el["ghost"], " <font color=red>" ..(discover.ghost_icon or "").. "</font>", "")

  rec.column_mac = [[<a href="]] ..ntop.getHttpPrefix().. [[/lua/mac_details.lua?host=]] ..el["mac"].. [[">]] ..get_symbolic_mac(el["mac"], true).. [[</a>]]
  rec.column_name = el.name
  rec.column_info = el.info
  rec.column_device = el["device_label"]
  rec.column_manufacturer = el.manufacturer
  rec.column_os = el.os

  res[#res + 1] = rec

::continue::
end

if(enable_doa_ox) then
  doa_ox.term(doa_ox_fd)
end

-- ################################################

rest_utils.extended_answer(rest_utils.consts.success.ok, res, {
  ["recordsFiltered"] = #res,
  ["recordsTotal"] = #res
})
