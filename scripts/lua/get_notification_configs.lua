--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local notification_configs = require("notification_configs")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

if not haveAdminPrivileges(true) then
    return
end

local endpoints = notification_configs.get_configs()

-- Exclude builtin configs
-- These configs will be non-editable and non-deletable
local res = {}
for _, config in pairs(endpoints) do
   res[#res + 1] = config
end

print(json.encode(res))
