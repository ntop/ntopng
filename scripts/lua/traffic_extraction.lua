--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('application/json')

local res = {}

if not recording_utils.isAvailable() then
  res.error = i18n("traffic_recording.not_granted") 
else
  if _GET["epoch_begin"] == nil or _GET["epoch_end"] == nil then
    res.error = i18n("traffic_recording.missing_parameters")
  else

    interface.select(ifname)

    local ifstats = interface.getStats()

    local filter = _GET["bpf_filter"]
    local time_from = tonumber(_GET["epoch_begin"])
    local time_to = tonumber(_GET["epoch_end"])

    local params = {
      time_from = time_from,
      time_to = time_to,
      filter = filter,
    }

    local job_info = recording_utils.scheduleExtraction(ifstats.id, params)

    res.id = job_info.id
  end
  res.csrf = ntop.getRandomCSRFValue()
end

print(json.encode(res))
