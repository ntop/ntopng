--
-- (C) 2013-26 - ntop.org
--


local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;".. package.path

require "http_lint"
local ascan_utils = require "ascan_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- A write: _POST (filled only with a valid CSRF)
local scan_frequency = _POST["scan_frequency"]

if isEmptyString(scan_frequency) or not ascan_utils.is_valid_scan_frequency(scan_frequency) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

if (scan_frequency == "disabled") then
    scan_frequency = nil
end

local result = ascan_utils.update_all_periodicity(scan_frequency)

if result then
    rest_utils.answer(rest_utils.consts.success.ok, result)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
