--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path


-- http_lint (validates _GET/_POST) + the light modules of rest_utils, not the whole lua_utils
require "http_lint"
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
