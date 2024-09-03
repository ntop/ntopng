
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local json = require "dkjson"

local ifid = tonumber(_GET["ifid"])


local res = {}

-- Get data from redis: expected format, array of objects with keys: 
res = {{key= "unexpected_dhcp", value_description="192.168.2.85, 192.168.2.45" or "", is_enabled=true or false}}


if isEmptyString(ifid) then
    rest_utils.answer(rest_utils.consts.err.invalid_interface)
    return
end

rest_utils.answer(rest_utils.consts.success.ok, res)