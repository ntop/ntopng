--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

if not isAdministratorOrPrintErr() then
  return
end

ntop.serviceRestart()

res = { }

print(json.encode(res, nil, 1))
