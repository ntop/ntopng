--
-- (C) 2017-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

if not haveAdminPrivileges() then
  return
end

ntop.serviceRestart()

res = { csrf = ntop.getRandomCSRFValue() }

print(json.encode(res, nil, 1))
