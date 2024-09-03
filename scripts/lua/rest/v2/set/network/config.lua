
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local json = require "dkjson"

local action = _GET["action"]
local post_data = _POST["payload"]

local res = {}

local config = _POST["config"]
tprint(_POST)

local data = json.decode(config)

-- data is:
--[[
asset_key = [ "gateway", "unexpected_dhcp", "unexpected_dns", "unexpected_ntp", "unexpected_smtp"]

{ "csrf":..., "config": [ {"asset_key": asset_key, "item": [ip1, ip2, ip3...]}, {"asset_key": asset_key_1, "item": [ip1, ip2, ip3...]}]}
]]

-- local script_key = post_data["asset_key"] -- asset_key
-- local redis_key = "ntopng.prefs." .. script_key .. "_ip_list"

-- for each element in respone: ntop.getCache(redis_key)

if isEmptyString(ifid) then
    rest_utils.answer(rest_utils.consts.err.invalid_interface)
    return
end


rest_utils.answer(rest_utils.consts.success.ok, res)