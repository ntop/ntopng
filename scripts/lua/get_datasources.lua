--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local datasources_utils = require("datasources_utils")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

local datasources = datasources_utils.get_all_sources()
print(json.encode(datasources))
