--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local auth = require "auth"
local rest_utils = require "rest_utils"
local am_utils = require "am_utils"
local active_monitoring = require "active_monitoring"

-- ################################################

local action      = _POST["action"]
local host        = _POST["am_host"]
local measurement = _POST["measurement"]
local ifname      = _POST["ifname"]
local threshold   = _POST["threshold"]
local granularity = _POST["granularity"]

local res = {}
local rc  = rest_utils.consts.success.ok

-- ################################################

if isEmptyString(action) then
    res.result = i18n("active_monitoring_stats.empty_action")
    rest_utils.answer(rc, res)
    return
end

-- ################################################

if isEmptyString(host) then
    res.result = i18n("missing_x_parameter", { param = "Host" })
    rest_utils.answer(rc, res)
    return
end

-- ################################################

if isEmptyString(measurement) then
    res.result = i18n("missing_x_parameter", { param = "Measurement" })
    rest_utils.answer(rc, res)
    return
end

-- ################################################

if not auth.has_capability(auth.capabilities.active_monitoring) then
    res.result = i18n("not_admin")
    rest_utils.answer(rc, res)
    return
end

-- ################################################

if action == "add" then
    local ok, err = active_monitoring.add_am_script(host, measurement, ifname, threshold, granularity)
    if not ok then
        res.result = err
    else
        res.result = "ok"
    end

elseif action == "edit" then
    local old_am_host    = _POST["old_host"]
    local old_measurement = _POST["old_measurement"]

    local ok, err = active_monitoring.edit_am_script(host, measurement, ifname, threshold, granularity,
                                                      old_am_host, old_measurement)
    if not ok then
        res.result = err
    else
        res.result = "ok"
    end

else
    res.result = i18n("active_monitoring_stats.empty_action")
end

-- ################################################

rest_utils.answer(rc, res)
