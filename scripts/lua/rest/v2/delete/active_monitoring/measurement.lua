--
-- (C) 2019-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local auth = require "auth"
local rest_utils = require "rest_utils"
local active_monitoring = require "active_monitoring"

-- ################################################

local host = _POST["host"]
local measurement = _POST["measurement"]

local res, err_msg = active_monitoring.delete_am_script(host, measurement)

local rc = rest_utils.consts.success.ok

if not res then
    rc = rest_utils.consts.err.invalid_args
end
rest_utils.answer(rc, res)
