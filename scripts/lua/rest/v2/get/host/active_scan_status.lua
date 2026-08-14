--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path


require "lua_utils"
local rest_utils = require "rest_utils"
local ascan_utils = require "ascan_utils"
local total, total_in_progress = ascan_utils.check_in_progress_status()

local rsp =  {
    total = total,
    total_in_progress = total_in_progress,
    total_in_success = total - total_in_progress
}
rest_utils.answer(rest_utils.consts.success.ok, {rsp = rsp})