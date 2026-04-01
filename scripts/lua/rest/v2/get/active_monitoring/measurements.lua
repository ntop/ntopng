--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ####################################

require "http_lint"
require "check_redis_prefs"
require "ntop_utils"
local active_monitoring_utils = require "am_utils"
local rest_utils = require "rest_utils"
local active_monitoring = require "active_monitoring"

local rc = rest_utils.consts.success.ok
-- ################################################

local rsp = active_monitoring.get_am_defs()

-- ################################################

rest_utils.answer(rc, rsp)
