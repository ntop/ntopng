--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('application/json')

if not recording_utils.isAvailable() then
  local msg = i18n("traffic_recording.not_granted")
  print(json.encode({error = msg}))
elseif _GET["epoch_begin"] == nil or _GET["epoch_end"] == nil then
  local msg = i18n("traffic_recording.missing_parameters")
  print(json.encode({error = msg}))
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

  print(json.encode(job_info))

end
