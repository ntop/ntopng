--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local script_manager = require("script_manager")
local am_utils = require "am_utils"
local format_utils = require "format_utils"

sendHTTPContentTypeHeader('application/json')
  
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
    local column_label = am_host.label
    local column_html_label = ""

    if am_host.measurement == 'icmp' or am_host.measurement == 'cicmp' then
      column_ifname = am_host.ifname or ""
    end

    if (last_update) and (am_host.measurement == 'throughput') then
      last_update.value = format_utils.bitsToSize(last_update.value * 8 --[[ Stored in bytes ]])
    end

    if(last_update ~= nil) then
       column_last_update = last_update.when
       column_last_value = last_update.value
       column_last_ip = last_update.ip
    end
    
    if not isEmptyString(column_last_ip) then
      if string.starts(column_last_ip, 'http') then
        column_last_ip = split(column_last_ip, '//')[2]
        if string.find(column_last_ip, '/') then
          column_last_ip = split(column_last_ip, '/')[1]
        end
      end
    end

    if(am_host.is_infrastructure) then
      package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
      local infrastructure_utils = require("infrastructure_utils")
      local infrastructure_instance = infrastructure_utils.get_instance_by_host(column_last_ip)

      if infrastructure_instance then
        column_label = string.format('%s [Infrastructure]', infrastructure_instance.alias)
        column_html_label = string.format('%s <i class="fas fa-building"></i>', infrastructure_instance.alias)
        am_host.host = column_last_ip
      end
    end

    if isEmptyString(column_last_value) then
      chart = ""
    else
      if m_info.value_formatter then
        column_last_value = m_info.value_formatter(column_last_value)
      end
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

    if isEmptyString(column_html_label) then
      column_html_label = am_utils.formatAmHost(am_host.host, am_host.measurement, true)
    end

    if(column_ifname ~= "") then
       column_html_label = column_html_label .. " [ <span class=\"fas fa-ethernet\"></span> "..column_ifname.." ]"
    end
    
    res[#res + 1] = {
       key = key,
       label = column_label,
       html_label = column_html_label,
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

print(json.encode(res))
