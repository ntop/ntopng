--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local json = require "dkjson"
local system_scripts = require("system_scripts_utils")

local probe = system_scripts.getSystemProbe("redis")

sendHTTPContentTypeHeader('application/json')

local stats = probe.getStats()

print(json.encode(stats))
