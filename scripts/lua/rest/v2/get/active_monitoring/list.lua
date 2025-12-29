--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ####################################

require "http_lint"
require "check_redis_prefs"
local am_utils = require "am_utils"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local measurement = _GET["measurement"]
local alerted = _GET["only_alerted_hosts"]
local res = {}

if not isEmptyString(alerted) then
    alerted = alerted == '1'
end

-- ################################################

local active_monitoring_hosts = am_utils.getHosts() or {}

for key, info in pairs(active_monitoring_hosts) do
    local last_measurement = am_utils.getMeasurementInfo(info.measurement)
    local is_alerted = am_utils.hasAlerts(info)

    if not last_measurement then
        goto continue
    end

    -- Filters applied
    if not isEmptyString(measurement) and measurement ~= info.measurement then
        goto continue
    end

    if not isEmptyString(alerted) and alerted ~= is_alerted then
        goto continue
    end

    -- Format the data
    local ip_address = ''
    local last_measurement_time = 0
    local measurement_value = ''
    local last_mean = ''
    local last_jitter = ''
    local hourly_stats, availability = am_utils.getAvailability(info.host, info.measurement)
    local last_update = am_utils.getLastAmUpdate(info.host, info.measurement)
    
    if last_update then
        ip_address = last_update.ip
        measurement_value = last_update.value
        last_measurement_time = last_update.when
        last_mean = last_update.mean
        last_jitter = last_update.jitter

        if info.measurement == "speedtest" then
            measurement_value = format_utils.bytesToBPS(measurement_value)
        end
    end

    -- Clean the IP Address in case of http
    if not isEmptyString(ip_address) and string.find(ip_address, '//') then
        ip_address = split(ip_address, '//')[2]
        if string.find(ip_address, '/') then
            ip_address = split(ip_address, '/')[1]
        end
    end

    if ip_address == info.label then
        info.label = ip2label(ip_address)
    end

    local custom_name = getHumanReadableInterfaceName(info.ifname)
    if isEmptyString(custom_name) then custom_name = nil end

    res[#res + 1] = {
        key = key,
        ip_address = ip_address,
        threshold = info.threshold,
        hourly_stats = hourly_stats or {},
        am_host = info.host, -- This is used by http_src/constants/metrics-consts.js
        target = {
            name = info.label,
            host = info.host
        },
        last_measurement = {
            measurement_type = info.measurement,
            measurement_value = measurement_value,
            last_measurement_time = last_measurement_time,    
        },
        metadata = {
            is_infrastructure_instance = info.is_infrastructure,
            is_alerted = is_alerted,
            interface_name = custom_name or info.ifname,
            interface_id = getInterfaceId(info.ifname),
            granularity = info.granularity,
            availability = availability or "",
            unit = last_measurement.i18n_unit,
            timeseries = (areSystemTimeseriesEnabled() and not isEmptyString(measurement_value))
        },
        extra_measurements = {
            mean = last_mean,
            jitter = last_jitter
        }
    }
    ::continue::
end

-- ################################################

rest_utils.answer(rc, res)
