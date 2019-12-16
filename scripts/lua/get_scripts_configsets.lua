--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")

local rv = user_scripts.getConfigsets()

sendHTTPContentTypeHeader('application/json')

print(json.encode(rv))
