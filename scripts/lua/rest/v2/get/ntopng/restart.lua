--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"
local rest_utils = require("rest_utils")
local rc = rest_utils.consts.success.ok

--
-- Restart ntopng
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/ntopng/restart.lua
--

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

if not ntop.serviceRestart() then
    rest_utils.answer(rest_utils.consts.err.internal_error)
    return
end

rest_utils.answer(rc)
