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

-- ################################################

if isEmptyString(ifid) then
    ifid = interface.getId()
end

interface.select(ifid)

local res = {}

local discovered = discover.discover2table(ifname)

-- ################################################

if (discovered["devices"] ~= nil) then
    for _, value in pairs(discovered["devices"]) do
        local record = {}

        local manufacturer = ""
        if value["manufacturer"] then
            manufacturer = value["manufacturer"]
        else
            manufacturer = get_manufacturer_mac(value["mac"])
        end

        value.manufacturer = manufacturer

        -- Name
        local name = ""
        if value["sym"] then
            name = value["sym"]
        end

        if value["symIP"] then
            if value["sym"] then
                name = name .. " [" .. value["symIP"] .. "]"
            else
                name = value["symIP"]
            end
        end
        value.name = name

        -- Retrieve information from L3 host
        local host = interface.getHostInfo(value["ip"])

        if host ~= nil then
            value.os_type = host.os
        end

        value.os = value.os_type or 0

        -- Device info
        local devinfo = ""
        if value["information"] then
            devinfo = table.concat(value["information"], "; ")
        end
        if value["url"] then
            if value["information"] then
                devinfo = devinfo .. "; " .. value["url"]
            else
                devinfo = value["url"]
            end
        end
        value.info = devinfo

        -- Filter
        if (os_filter ~= nil) and (value.os_type ~= os_filter) then
            goto continue
        end
        if (manuf_filter ~= nil) then
            goto continue
        end

        if (devtype_filter ~= nil) and (discover.devtype2id(value.device_type) ~= devtype_filter) then
            goto continue
        end
        
        local record = {
            ip = value["ip"],
            mac_address = value["mac"],
            name = value.name,
            info = value.info,
            manufacturer = value.manufacturer,
            os = value.os,
            device_type = value["device_type"],
            sym = value["sym"],
            ghost = value["ghost"],
            information = value["information"]
        }

        table.insert(res, record)
        ::continue::
    end
end
-- ################################################


rest_utils.answer(rest_utils.consts.success.ok, res)
