--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

if not haveAdminPrivileges() then
  return
end

local upgrade_request_key = "ntopng.updates.run_upgrade"

ntop.setCache(upgrade_request_key, "1", 600)

res = { csrf = ntop.getRandomCSRFValue() }

print(json.encode(res, nil, 1))
