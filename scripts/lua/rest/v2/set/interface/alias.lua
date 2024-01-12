--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Set host alias
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid" : "9", "custom_name" : "Mario's Interface"}' http://localhost:3000/lua/rest/v2/set/interface/alias.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(_POST["ifid"]) or isEmptyString(_POST["custom_name"]) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local interface = _POST["ifid"] 
local custom_name = _POST["custom_name"]

local res = setInterfaceAlias(interface, custom_name)

if res then
   rest_utils.answer(rest_utils.consts.success.ok)
else
   rest_utils.answer(rest_utils.consts.err.invalid_args)
end

