--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Set host alias
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"network_cidr" : "192.168.2.0/24", "custom_name" : "Mario's Network"}' http://localhost:3000/lua/rest/v2/set/network/alias.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(_POST["network_cidr"]) or isEmptyString(_POST["custom_name"]) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local network = _POST["network_cidr"]
local custom_name = _POST["custom_name"]

setLocalNetworkAlias(network, custom_name)

rest_utils.answer(rest_utils.consts.success.ok)

