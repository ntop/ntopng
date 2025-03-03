-- (C) 2013-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"

local host = _GET["host"]

if isEmptyString(host) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
end

-- Using pcall for error handling
local success, result = pcall(function()
    return vs_utils.get_ports(host)
end)

if success then
    rest_utils.answer(rest_utils.consts.success.ok, result)
else
    rest_utils.answer(rest_utils.consts.err.internal_error, {error = tostring(result)})
end