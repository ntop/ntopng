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

local action = _POST["action"]
local host = _POST["am_host"]
local measurement = _POST["measurement"]
local ifname = _POST["ifname"]

local res = {}

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
            res.result = i18n('active_monitoring_stats.invalid_host')
            return (false)
        end
    end

    return (true)
end

-- ################################################

if isEmptyString(action) then
    res.result = i18n('active_monitoring_stats.empty_action')
    rest_utils.answer(rest_utils.consts.success.ok, res)
    return
end

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

if not isValidHostMeasurementCombination(host, measurement) then
    rest_utils.answer(rest_utils.consts.success.ok, res)
    return
end

-- ################################################

local url = am_utils.formatAmHost(host, measurement)
if (action == "add") then
    local threshold = _POST["threshold"]
    local granularity = _POST["granularity"]

    -- If already existing simply do not add the host
    if not am_utils.hasHost(host, measurement) then
        am_utils.addHost(host, ifname, measurement, threshold, granularity)
    end

    res.result = 'ok'
elseif (action == "edit") then
    local threshold = _POST["threshold"]
    local granularity = _POST["granularity"]
    local old_am_host = _POST["old_host"]
    local old_measurement = _POST["old_measurement"]
    local old_granularity = _POST["old_granularity"]
    local old_url = am_utils.formatAmHost(old_am_host, old_measurement)

    if am_utils.getHost(old_am_host, old_measurement) then
        if ((old_am_host ~= host) or (old_measurement ~= measurement)) then
            -- The key has changed, delete the old host and create a new one
            am_utils.deleteHost(old_am_host, old_measurement) -- also calls discardHostTimeseries
            am_utils.addHost(host, ifname, measurement, threshold, granularity)
        else
            -- The key is the same, only update its settings
            am_utils.editHost(host, ifname, measurement, threshold, granularity)
        end
    end

    res.result = 'ok'
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, res)
