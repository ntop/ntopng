--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('application/json')

local res = {}

if not recording_utils.isAvailable() then
  res.error = i18n("traffic_recording.not_granted") 
else
  if _POST["epoch_begin"] == nil or _POST["epoch_end"] == nil then
    res.error = i18n("traffic_recording.missing_parameters")
  else
    interface.select(ifname)

    local ifstats = interface.getStats()

    local filter = _POST["bpf_filter"]
    local time_from = tonumber(_POST["epoch_begin"])
    local time_to = tonumber(_POST["epoch_end"])
    local chart_url = _POST["url"]
    local timeline_path
    if recording_utils.getCurrentTrafficRecordingProvider(ifstats.id) ~= "ntopng" then
       timeline_path = recording_utils.getCurrentTrafficRecordingProviderTimelinePath(ifstats.id)
    end

    local params = {
      time_from = time_from,
      time_to = time_to,
      filter = filter,
      chart_url = chart_url,
      timeline_path = timeline_path
    }

    local job_info = recording_utils.scheduleExtraction(ifstats.id, params)

    res.id = job_info.id
  end
end

print(json.encode(res))
