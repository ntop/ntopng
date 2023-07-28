--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"

local host = _GET["host"]
local scan_type = _GET["scan_type"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
end

local result = vs_utils.save_host_to_scan(scan_type, host) -- FIXME: add ports

if result == 1 then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
