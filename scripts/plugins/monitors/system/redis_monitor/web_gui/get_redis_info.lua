--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local checks = require("checks")
local json = require "dkjson"

local redis = checks.loadModule(getSystemInterfaceId(), checks.script_types.system, "system", "redis_monitor")

sendHTTPContentTypeHeader('application/json')

local stats = redis.getStats()

print(json.encode(stats))
