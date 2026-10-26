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

if not auth.has_capability(auth.capabilities.active_monitoring) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local host = _POST["am_host"]
local measurement = _POST["measurement"]

local res, err_msg = active_monitoring.delete_am_script(host, measurement)

local rc = rest_utils.consts.success.ok

if not res then
    rc = rest_utils.consts.err.invalid_args
end
rest_utils.answer(rc, res)
