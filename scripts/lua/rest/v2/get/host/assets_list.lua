--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local asset_utils = require "asset_utils"
local discover_utils = require "discover_utils"

-- ##########################################

-- NOTE: This rest is pretty much the same as assets.lua
-- the difference is that the values are not formatted, this is 
-- not used internally 

if not _GET["serial_key"] then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

-- ##########################################

local ifid = _GET["ifid"]

if not isEmptyString(ifid) then
    interface.select(ifid)
else
    ifid = interface.getId()
end

-- ##########################################

local rsp = {}
local serial_key = _GET["serial_key"]
local list = asset_utils.getInactiveHostInfo(ifid, serial_key) or {}

for _, asset in pairs(list or {}) do
    if not isEmptyString(asset.device_type) then
        asset.device_type = discover_utils.devtype2string(asset.device_type)
    end
    if not isEmptyString(asset.os_type) then
        asset.os_type = discover_utils.getOsAndIcon(asset.os_type)        
    end
    rsp[#rsp + 1] = asset
end

-- ##########################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)