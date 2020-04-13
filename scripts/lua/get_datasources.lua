--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local datasource_utils = require("datasource_utils")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

local datasources = datasource_utils.get_all_sources()
print(json.encode(datasources))