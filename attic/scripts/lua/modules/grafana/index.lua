--
-- (C) 2013-18 - ntop.org
--

-- This page is requested by grafana Simple JSON plugin when testing the datasource
-- datasource test involes a request to / that is mapped by ntopng to index.lua

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "grafana_utils"

local json = require("dkjson")

if isCORSpreflight() then
   processCORSpreflight()
else
   local corsr = {}
   corsr["Access-Control-Allow-Origin"] = _SERVER["Origin"]
   sendHTTPHeader('application/json', nil, corsr)
   print(json.encode({status="OK"}, nil))
end
