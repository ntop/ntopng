--
-- (C) 2019-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local am_utils = require "am_utils"
local auth = require "auth"
local rest_utils = require "rest_utils"

-- ################################################

local host = _POST["am_host"]
local measurement = _POST["measurement"]

local res = {}

-- ################################################

if isEmptyString(host) then
    res.result = i18n("missing_x_parameter", {
        param = 'Host'
    })
    rest_utils.answer(rest_utils.consts.success.ok, res)
    return
end

-- ################################################

if isEmptyString(measurement) then
    res.result = i18n("missing_x_parameter", {
        param = 'Measurement'
    })
    rest_utils.answer(rest_utils.consts.success.ok, res)
    return
end

-- ################################################

if not auth.has_capability(auth.capabilities.active_monitoring) then
    res.result = i18n("not_admin")
    rest_utils.answer(rest_utils.consts.success.ok, res)
    return
end

-- ################################################

local url = am_utils.formatAmHost(host, measurement)
local existing = am_utils.hasHost(host, measurement)

if existing then
    am_utils.deleteHost(host, measurement)
end

res.result = 'ok'

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, res)
