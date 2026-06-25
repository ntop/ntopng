--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"
local rest_utils = require("rest_utils")
local sys_utils  = require("sys_utils")

--
-- Reboot the nEdge
-- Example: curl -u admin:admin -X POST http://localhost:3000/lua/rest/v2/set/ntopng/reboot.lua
--

if not (ntop.isnEdge and ntop.isnEdge()) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

sys_utils.rebootSystem()
rest_utils.answer(rest_utils.consts.success.ok)
