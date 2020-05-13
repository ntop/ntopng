--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local notification_endpoints = require("notification_endpoints")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

if not haveAdminPrivileges(true) then
    return
end

local endpoints = notification_endpoints.get_configs()

print(json.encode(endpoints))
