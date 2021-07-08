--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local alert_severities = require "alert_severities"
local rest_utils = require "rest_utils"

--
-- Read all the defined alert severity constants
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/alert/severity/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

for severity, severity_descr in pairs(alert_severities) do
   res[#res + 1] = {
     severity = severity,
     id = severity_descr.severity_id,
   }
end

rest_utils.answer(rc, res)

