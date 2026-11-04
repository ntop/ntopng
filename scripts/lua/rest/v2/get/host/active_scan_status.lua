--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path

-- Polled by the Active Scan page every 10 seconds: rest_utils + the light
-- ascan_status_utils, not lua_utils/ascan_utils (no parameters to validate)
local rest_utils = require "rest_utils"
local ascan_status_utils = require "ascan_status_utils"

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local total, total_in_progress = ascan_status_utils.check_in_progress_status()

local rsp =  {
    total = total,
    total_in_progress = total_in_progress,
    total_in_success = total - total_in_progress
}
rest_utils.answer(rest_utils.consts.success.ok, {rsp = rsp})
