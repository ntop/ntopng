--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local user_scripts = require("user_scripts")
local json = require "dkjson"

local redis = user_scripts.loadModule(getSystemInterfaceId(), user_scripts.script_types.system, "system", "redis_monitor")

sendHTTPContentTypeHeader('application/json')

local stats = redis.getStats()

print(json.encode(stats))
