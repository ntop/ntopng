--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ####################################

require "http_lint"
require "check_redis_prefs"
local am_utils = require "am_utils"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local active_monitoring = require "active_monitoring"

-- Same access as the Active Monitoring page (system interface)
if not isAllowedSystemInterface() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local measurement = _GET["measurement"]
local alerted = _GET["only_alerted_hosts"]

local res = active_monitoring.list_am_scripts(ifid, measurement, alerted)



rest_utils.answer(rc, res)
