--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local demo_utils = require "demo_utils"

--
-- List every registered demo tour with its should_show status for the current user
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/demo/status.lua"
--

local res = {}

local username = _SESSION and _SESSION["user"]

if isEmptyString(username) then
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

res.demos = demo_utils.get_status_for_user(username)

rest_utils.answer(rest_utils.consts.success.ok, res)
