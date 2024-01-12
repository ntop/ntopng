--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils  = require "rest_utils"
local json = require("dkjson")
local script_manager = require("script_manager")
local am_utils = require "am_utils"

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
       html_label = html_label,
       host = am_host.host,
       alerted = alerted,
       measurement = i18n(m_info.i18n_label),
       measurement_key = am_host.measurement,
       chart = chart,
       threshold = am_host.threshold,
       last_measure = column_last_value or "",
       value_js_formatter = m_info.value_js_formatter,
       last_mesurement_time = column_last_update,
       last_ip = column_last_ip,
       ifname = column_ifname,
       granularity = am_host.granularity,
       availability = availability or "",
       hours = hourly_stats or {},
       unit = i18n(m_info.i18n_unit) or m_info.i18n_unit,
       jitter = column_jitter,
       readonly = am_host.readonly
    }

    ::continue::
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, res)
