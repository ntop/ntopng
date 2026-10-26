--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ################################################

require "http_lint"
require "check_redis_prefs"
local rest_utils = require "rest_utils"
local active_monitoring_utils = require "am_utils"

-- Same access as the Active Monitoring page (system interface)
if not isAllowedSystemInterface() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local res = {}
local measurements_info = {}

-- ################################################

local active_monitoring_hosts = active_monitoring_utils.getHosts() or {}
local measurement_types = active_monitoring_utils.getMeasurementsInfo()
local measurement_filters = {{
    key = "measurement",
    value = "",
    label = i18n("all")
}}
local tmp_filters = {}
for key, info in pairs(active_monitoring_hosts) do
    tmp_filters[i18n('active_monitoring_page.' .. info.measurement)] = {
        key = "measurement",
        value = info.measurement,
        label = i18n('active_monitoring_page.' .. info.measurement)
    }
end
for _, info in pairsByKeys(tmp_filters, asc) do
    measurement_filters[#measurement_filters + 1] = info
end

res[#res + 1] = {
    action = "measurement",
    label = i18n("active_monitoring_page.measurement"),
    name = "measurement",
    value = measurement_filters
}

res[#res + 1] = {
    action = "only_alerted_hosts",
    label = i18n("active_monitoring_page.alert_status"),
    name = "only_alerted_hosts",
    value = {{
        key = "only_alerted_hosts",
        value = "",
        label = i18n("all")
    }, {
        key = "only_alerted_hosts",
        value = "1",
        label = i18n("active_monitoring_page.alerted")
    }, {
        key = "only_alerted_hosts",
        value = "0",
        label = i18n("active_monitoring_page.not_alerted")
    },}
}

-- ################################################

rest_utils.answer(rc, res)