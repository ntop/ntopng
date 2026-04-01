--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ####################################

require "check_redis_prefs"
require "ntop_utils"
local am_utils = require "am_utils"
local auth = require "auth"

local am = {}

local function isValidHostMeasurementCombination(host, measurement)
    -- Strips the prefix (either http:// or https://) and a possible port

    -- Extract the domain, e.g.,
    -- http://user:password@www.example.com/p1/p2 becomes www.example.com
    -- http://www.example.com:3000/p1/p2 becomes www.example.com

    -- See if domain has user and password encoded, i.e.,
    -- http://user:password@www.example.com becomes www.example.com
    local domain = host:match('^%w+://[^:]+:[^@]+@([^/:]+)')

    if not domain then
        -- Domain has no user and password encoded, i.e.,
        -- http://www.example.com:3000/p1/p2
        domain = host:match('^%w+://([^/:]+)')
    end

    -- Take the domain (if found) or the host as-is
    host = domain or host

    local host_v4 = isIPv4(host)
    local host_v6 = isIPv6(host)

    if not host_v4 and not host_v6 then
        -- Host is a domain, try to resolve it as ipv4, then ipv6
        if ntop.resolveHost(host, true) then
            -- Valid Host
            return (true)
        elseif ntop.resolveHost(host, false) then
            -- Valid Host
            return (true)
        else
            return (false)
        end
    end

    return (true)
end

-- ################################################

-- lists active monitoring scripts definitions
function am.get_am_defs()
    local rsp = {}
    local measurements_info = {}

    for key, info in pairs(am_utils.getMeasurementsInfo()) do
        if key == "vulnerability_scan" or key == "cve_changes_detected" or key == "ports_changes_detected" then
            goto continue
        end
        local label = i18n(info.i18n_label) or info.i18n_label
        local unit = i18n(info.i18n_unit) or info.i18n_unit

        measurements_info[key] = {
            label = label,
            granularities = am_utils.getAvailableGranularities(key),
            key = key,
            operator = info.operator,
            unit = unit,
            force_host = info.force_host,
            max_threshold = info.max_threshold,
            default_threshold = info.default_threshold
        }

        ::continue::
    end

    for _, info in pairsByKeys(measurements_info, asc) do
        rsp[#rsp + 1] = info
    end
    return rsp
end

-- lists am activated scripts
function am.list_am_scripts(ifid, measurement, alerted)
    
    local res = {}

    if not isEmptyString(alerted) then
        alerted = alerted == '1'
    end

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
    return res
end

-- ################################################

-- Adds a new AM host if it does not already exist.
-- Returns true on success, false + error string on failure.
function am.add_am_script(host, measurement, ifname, threshold, granularity)
    if isEmptyString(host) then
        return false, i18n("missing_x_parameter", { param = "Host" })
    end

    if isEmptyString(measurement) then
        return false, i18n("missing_x_parameter", { param = "Measurement" })
    end

    -- invalid active monitoring combination
    if not isValidHostMeasurementCombination(host, measurement) then
        return false, i18n('active_monitoring_stats.invalid_host')
    end

    if not am_utils.hasHost(host, measurement) then
        am_utils.addHost(host, ifname, measurement, threshold, granularity)
    end

    return true, nil
end

-- ################################################

-- Edits an existing AM host entry.
-- If the key (host + measurement) has changed, deletes the old entry and creates a new one.
-- If only the settings changed, updates them in place.
-- Returns true on success, false + error string on failure.
function am.edit_am_script(host, measurement, ifname, threshold, granularity,
                                                  old_am_host, old_measurement)
    if isEmptyString(host) then
        return false, i18n("missing_x_parameter", { param = "Host" })
    end

    if isEmptyString(measurement) then
        return false, i18n("missing_x_parameter", { param = "Measurement" })
    end

    -- invalid active monitoring combination
    if not isValidHostMeasurementCombination(host, measurement) then
        return false, i18n('active_monitoring_stats.invalid_host')
    end

    if not am_utils.getHost(old_am_host, old_measurement) then
        return false, i18n("active_monitoring_stats.invalid_host")
    end

    if (old_am_host ~= host) or (old_measurement ~= measurement) then
        -- Key has changed: replace old entry with a new one
        am_utils.deleteHost(old_am_host, old_measurement)
        am_utils.addHost(host, ifname, measurement, threshold, granularity)
    else
        -- Key unchanged: update settings in place
        am_utils.editHost(host, ifname, measurement, threshold, granularity)
    end

    return true, nil
end

-- ################################################
function am.delete_am_script(host, measurement)

    if isEmptyString(host) then
        return false, i18n("missing_x_parameter", { param = 'Host' })
    end

    if isEmptyString(measurement) then
        return false, i18n("missing_x_parameter", { param = 'Measurement' })
    end

    if not auth.has_capability(auth.capabilities.active_monitoring) then
        return false, i18n("not_admin") 
    end

    local existing = am_utils.hasHost(host, measurement)

    if existing then
        am_utils.deleteHost(host, measurement)
    end

    return true, nil
end

-- ################################################

return am