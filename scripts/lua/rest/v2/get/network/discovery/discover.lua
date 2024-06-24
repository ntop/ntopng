--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local discover = require "discover_utils"
local rest_utils = require "rest_utils"

local ifid = tostring(_GET["ifid"]) or ""
local os_filter = tonumber(_GET["operating_system"])
local devtype_filter = tonumber(_GET["device_type"])
local manuf_filter = _GET["manufacturer"]

-- ################################################

if isEmptyString(ifid) then
  ifid = interface.getId()
end

interface.select(ifid)

local res = {}

local discovered = discover.discover2table(ifname)

-- ################################################

discovered["devices"] = discovered["devices"] or {}

for _, value in pairs(discovered["devices"]) do
  -- Manufacturer
  local manufacturer = ""
  if value["manufacturer"] then
    manufacturer = value["manufacturer"]
  else
    manufacturer = get_manufacturer_mac(value["mac"])
  end

  local actual_manuf = manufacturer

  if(value["modelName"] and (value["modelName"] ~= "")) then
    manufacturer = manufacturer .. " ["..value["modelName"].."]"
  end
  value.manufacturer = manufacturer

  -- Name
  local name = ""
  if value["sym"] then name = name .. value["sym"] end

  if value["symIP"] then
    if value["sym"] then
      name = name .. " ["..value["symIP"].."]"
    else
      name = value["symIP"]
    end
  end
  value.name = name

  -- Retrieve information from L3 host
  local host = interface.getHostInfo(value["ip"])

  if(host ~= nil) then
    value.os_type = host.os
  end

  value.os = discover.getOsIcon(value.os_type)

  -- Device info
  local devinfo = ""
  if value["information"] then devinfo = devinfo .. table.concat(value["information"], "<br>") end
  if value["url"] then
    if value["information"] then
      devinfo = devinfo .. "<br>"..value["url"]
    else
      devinfo = devinfo .. value["url"]
    end
  end
  value.info = devinfo

  -- Filter
  if (os_filter ~= nil) and (value.os_type ~= os_filter) then
    goto continue
  end
  if (manuf_filter ~= nil) and (actual_manuf ~= manuf_filter) then
    goto continue
  end

  if (devtype_filter ~= nil) and (discover.devtype2id(value.device_type) ~= devtype_filter) then
    goto continue
  end

  local rec = {}
  
  rec.ip = ip2detailshref(value["ip"], nil, nil, value["ip"])
    ..ternary(value["icon"], "&nbsp;" ..(value["icon"] or "").. "&nbsp;", "")
    ..ternary(value["ghost"], " <font color=red>" ..(discover.ghost_icon or "").. "</font>", "")

  rec.mac_address = [[<a href="]] ..ntop.getHttpPrefix().. [[/lua/mac_details.lua?host=]] ..value["mac"].. [[">]] ..get_symbolic_mac(value["mac"], true).. [[</a>]]
  rec.name = value.name
  rec.info = value.info
  rec.device = value["device_label"]
  rec.manufacturer = value.manufacturer
  rec.os = value.os

  res[#res + 1] = rec

::continue::
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, res)
