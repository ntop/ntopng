--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

sendHTTPContentTypeHeader('application/json')

local charts_available = plugins_utils.timeseriesCreationEnabled()

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
      chart = plugins_utils.getUrl('active_monitoring_stats.lua') .. '?am_host='.. am_host.host ..'&measurement='.. am_host.measurement ..'&page=historical'
    end

    local column_last_ip = ""
    local column_last_update = ""
    local column_last_value = ""
    local last_update = am_utils.getLastAmUpdate(am_host.host, am_host.measurement)
    local alerted = 0
    
    if(last_update ~= nil) then
      local tdiff = os.time() - last_update.when

      if(tdiff <= 600) then
        column_last_update  = secondsToTime(tdiff).. " " ..i18n("details.ago")
      else
        column_last_update = format_utils.formatPastEpochShort(last_update.when)
      end

      column_last_value = last_update.value
      column_last_ip = last_update.ip
    end

    column_last_value = tonumber(column_last_value)

    if(column_last_value == nil) then
      chart = ""
    else
      if am_utils.hasExceededThreshold(am_host.threshold, m_info.operator, column_last_value) then
	alerted = 1
      else
	alerted = 0
      end
    end
    
    res[#res + 1] = {
       key = key,
       url = am_host.label,
       host = am_host.host,
       alerted = alerted,
       measurement = am_host.measurement,
       chart = chart,
       threshold = am_host.threshold,
       last_measure = column_last_value or "",
       value_js_formatter = m_info.value_js_formatter,
       last_mesurement_time = column_last_update,
       last_ip = column_last_ip,
       granularity = am_host.granularity,
       availability = availability or "",
       hourly_stats = hourly_stats or {},
       unit = i18n(m_info.i18n_unit) or m_info.i18n_unit,
    }

    ::continue::
end

-- ################################################

print(json.encode(res))
