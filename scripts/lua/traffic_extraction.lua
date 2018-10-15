--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local recording_utils = require "recording_utils"

sendHTTPContentTypeHeader('application/json')

if not recording_utils.isAvailable() then
  local msg = i18n("traffic_recording.not_granted")
  print(json.encode({error = msg}))
else if _GET["from"] == nil or _GET["to"] == nil then
  local msg = i18n("traffic_recording.missing_parameters")
  print(json.encode({error = msg}))
else

  interface.select(ifname)

  local filer = _GET["bpf_filter"]
  local time_from = tonumber(_GET["from"])
  local time_to = tonumber(_GET["to"])

  local params = {
    time_from = time_from,
    time_to = time_to,
    filter = filter
  }

  local job_info = recording_utils.schedule_extraction(interface.id, params)

  print(json.encode(job_info))

end
