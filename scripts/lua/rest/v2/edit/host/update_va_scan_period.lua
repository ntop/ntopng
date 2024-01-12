--
-- (C) 2013-24 - ntop.org
--


local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;".. package.path

local vs_utils = require "vs_utils"
local rest_utils = require "rest_utils"

local scan_frequency = _GET["scan_frequency"]
if (scan_frequency == "disabled") then
    scan_frequency = nil
end

local result = vs_utils.update_all_periodicity(scan_frequency) 

if result then
    rest_utils.answer(rest_utils.consts.success.ok, result)
end