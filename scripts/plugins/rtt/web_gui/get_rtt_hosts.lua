--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")
local rtt_utils = require("rtt_utils")
local plugins_utils = require("plugins_utils")

sendHTTPContentTypeHeader('application/json')

local charts_available = plugins_utils.timeseriesCreationEnabled()

-- ################################################

local rtt_hosts = rtt_utils.getHosts()

local res = {}

for key, rtt_host in pairs(rtt_hosts) do
    local chart = ""
    local m_info = rtt_utils.getMeasurementInfo(rtt_host.measurement)

    if not m_info then
      goto continue
    end

    if charts_available then
      chart = plugins_utils.getUrl('rtt_stats.lua') .. '?rtt_host='.. rtt_host.host ..'&measurement='.. rtt_host.measurement ..'&page=historical'
    end

    local column_last_ip = ""
    local column_last_update = ""
    local column_last_rtt = ""
    local last_update = rtt_utils.getLastRttUpdate(rtt_host.host, rtt_host.measurement)

    if(last_update ~= nil) then
      local tdiff = os.time() - last_update.when

      if(tdiff <= 600) then
        column_last_update  = secondsToTime(tdiff).. " " ..i18n("details.ago")
      else
        column_last_update = format_utils.formatPastEpochShort(last_update.when)
      end

      column_last_rtt = last_update.value
      column_last_ip = last_update.ip
    end

    if(column_last_rtt == "") then chart = "" end

    res[#res + 1] = {
       key = key,
       url = rtt_host.label,
       host = rtt_host.host,
       measurement = rtt_host.measurement,
       chart = chart,
       threshold = rtt_host.max_rtt,
       last_rtt = column_last_rtt,
       last_mesurement_time = column_last_update,
       last_ip = column_last_ip,
       granularity = rtt_host.granularity,
       unit = i18n(m_info.i18n_unit) or m_info.i18n_unit,
    }

    ::continue::
end

-- ################################################

print(json.encode(res))
