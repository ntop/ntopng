
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local json = require "dkjson"

local action = _GET["action"]
local post_data = json.decode(_POST["payload"])

local res = {}

-- Get data from redis: expected format, array of objects with keys: 
if (action == "get") then
    res = {{key= script_key, value_description="192.168.2.85, 192.168.2.45" or "", is_enabled=true or false}}
else
    local script_key = post_data["script_key"] -- gateway, unexpected_XXX
    local script_subdir = post_data["check_subdir"]
    local config = post_data["JSON"]
    local redis_key = "ntopng.prefs." .. script_key .. "_ip_list"
    local data = json.decode(config)

    --[[
    table
    all table
    all.script_conf table
    all.script_conf.items table
    all.script_conf.items.1 string 192.168.2.73
    all.script_conf.items.2 string 192.168.2.70
    all.enabled boolean true

    ]]
end

if isEmptyString(ifid) then
    rest_utils.answer(rest_utils.consts.err.invalid_interface)
    return
end




rest_utils.answer(rest_utils.consts.success.ok, res)