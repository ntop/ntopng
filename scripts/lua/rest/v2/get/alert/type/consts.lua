--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local alert_consts = require "alert_consts"
local rest_utils = require "rest_utils"

--
-- Read all the defined alert type constants
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/alert/type/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts.success.ok
local res = {}

for alert_type, alert in pairs(alert_consts.alert_types) do
   res[#res + 1] = {
      type = alert_type,
      key = alert.meta.alert_key,
   }
end

print(rest_utils.rc(rc, res))

