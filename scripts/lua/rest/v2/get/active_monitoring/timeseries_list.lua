--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if ntop.isEnterprise() then
    package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
end

require "lua_utils"
local rest_utils  = require "rest_utils"
local json = require("dkjson")
local script_manager = require("script_manager")
local am_utils = require "am_utils"
local infrastructure_utils = nil
if ntop.isEnterprise() then
    infrastructure_utils = require("infrastructure_utils")
end
--
-- List of active monitoring hosts (replaces get_active_monitoring_hosts.lua)
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{ }' http://localhost:3000/lua/rest/v2/get/am_host/list.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

-- sendHTTPContentTypeHeader('application/json')

local charts_available = script_manager.systemTimeseriesEnabled()

-- ################################################

local am_hosts = am_utils.getHosts()

local res = {}

for key, am_host in pairs(am_hosts) do
    local chart = ""
    local m_info = am_utils.getMeasurementInfo(am_host.measurement)
    local hourly_stats, availability = am_utils.getAvailability(am_host.host, am_host.measurement)

    if not m_info then
      goto continue
    end

    if charts_available then
      chart = script_manager.getMonitorUrl('active_monitoring_monitor.lua') .. '?am_host='.. am_host.host ..'&measurement='.. am_host.measurement ..'&page=historical'
    end

    local column_last_ip = ""
    local column_last_update = ""
    local column_last_value = ""
    local column_jitter = ""
    local column_ifname = ""
    local last_update = am_utils.getLastAmUpdate(am_host.host, am_host.measurement)
    local alerted = 0

    if am_host.measurement == 'icmp' or am_host.measurement == 'cicmp' then
      column_ifname = am_host.ifname or ""
    end

    if(last_update ~= nil) then
       column_last_update = last_update.when
       column_last_value = last_update.value
       column_last_ip = last_update.ip
    end

    column_last_value = tonumber(column_last_value)

    if(column_last_value == nil) then
      chart = ""
    end

    if am_utils.hasAlerts(am_host) then
       alerted = 1
    else
       alerted = 0
    end

    if last_update and last_update.jitter and last_update.mean and (last_update.jitter > 0 or last_update.mean > 0) then
	local jitter_unit = ""

	if m_info.i18n_jitter_unit then
	    jitter_unit = i18n(m_info.i18n_jitter_unit) or m_info.i18n_jitter_unit or ""
	end

	column_jitter = string.format("%.1f / %.1f %s", last_update.mean, last_update.jitter, jitter_unit)
    end

    local html_label = am_utils.formatAmHost(am_host.host, am_host.measurement, true)

    if(column_ifname ~= "") then
       html_label = html_label .. " [ <span class=\"fas fa-ethernet\"></span> "..column_ifname.." ]"
    end
    
    res[#res + 1] = {
       key = key,
       label = am_host.label,
       host = am_host.host,
       measurement = i18n(m_info.i18n_label),
       measurement_key = am_host.measurement,
       last_measure = column_last_value or "",
       last_ip = column_last_ip,
       ifname = column_ifname,
    }

    ::continue::
end


if infrastructure_utils then
    local infrastructure_instances = infrastructure_utils.get_all_instances()

    for _, instance in pairs(infrastructure_instances or {}) do
        local host = instance.url
        local measurement_host_tag = instance.url
        if table.len(measurement_host_tag:split("//")) == 2 then
            measurement_host_tag = measurement_host_tag:split("//")[2]
        end
        if table.len(measurement_host_tag:split(":")) == 2 then
            measurement_host_tag = measurement_host_tag:split(":")[1]
        end
        res[#res + 1] = {
            label = host,
            host = measurement_host_tag,
            measurement = '<i class="fas fa-building"></i>',
            measurement_key = "infrastructure"
        }
    end
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, res)
