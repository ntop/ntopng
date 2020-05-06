--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local plugins_utils = require("plugins_utils")
local notification_endpoint_configs = plugins_utils.loadModule("notification_endpoints", "notification_endpoint_configs")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

if not isAdministrator() then
    print(json.encode({}))
end

local endpoints = notification_endpoint_configs.get_endpoint_configs()

print(json.encode(endpoints))
