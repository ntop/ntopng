--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

local matrix = interface.getArpStatsMatrixInfo()

sendHTTPContentTypeHeader('application/json')
print(json.encode(matrix, {indent = true}))
