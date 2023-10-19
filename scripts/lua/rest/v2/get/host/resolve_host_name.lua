--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path


require "lua_utils"
local rest_utils = require "rest_utils"

local host = _GET["host"]

if isEmptyString(host) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
end

local result = ntop.resolveHost(host,true)
-- FIXME 

if result == nil then
    result = "no_success"
end
rest_utils.answer(rest_utils.consts.success.ok, result)
