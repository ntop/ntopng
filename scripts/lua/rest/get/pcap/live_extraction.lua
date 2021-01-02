--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")
local recording_utils = require "recording_utils"

local function send_error(msg)
  sendHTTPContentTypeHeader('application/json')
  local res = {}
  res.error = msg
  print(json.encode(res))
end

if not recording_utils.isExtractionAvailable() then
  send_error(i18n("traffic_recording.not_granted"))
else
  if _GET["epoch_begin"] == nil or _GET["epoch_end"] == nil then
    send_error(i18n("traffic_recording.missing_parameters"))
  else
    interface.select(ifname)

    local ifid = tonumber(_GET["ifid"])
    local filter = _GET["bpf_filter"]
    local time_from = tonumber(_GET["epoch_begin"])
    local time_to = tonumber(_GET["epoch_end"])

    if ifid == nil then
      local ifstats = interface.getStats()
      ifid = ifstats.id
    end

    if filter == nil then
      filter = ""
    end

    local timeline_path
    if recording_utils.getCurrentTrafficRecordingProvider(ifid) ~= "ntopng" then
       timeline_path = recording_utils.getCurrentTrafficRecordingProviderTimelinePath(ifid)
    end

    local fname = time_from.."-"..time_to..".pcap"
    sendHTTPContentTypeHeader('application/vnd.tcpdump.pcap', 'attachment; filename="'..fname..'"')

    ntop.runLiveExtraction(ifid, time_from, time_to, filter, timeline_path)

  end
end

