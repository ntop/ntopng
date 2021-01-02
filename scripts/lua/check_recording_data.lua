--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local recording_utils = require "recording_utils"
local format_utils = require("format_utils")
local json = require("dkjson")

sendHTTPHeader('application/json')

if not recording_utils.isExtractionAvailable() then
  return
end

local epoch_begin = tonumber(_GET["epoch_begin"])
local epoch_end   = tonumber(_GET["epoch_end"])

interface.select(ifname)

local ifstats = interface.getStats()

local window_info = recording_utils.isDataAvailable(ifstats.id, epoch_begin, epoch_end)

if window_info.epoch_begin and window_info.epoch_end then
  window_info.epoch_begin_formatted = format_utils.formatEpochShort(window_info.epoch_begin, window_info.epoch_end, window_info.epoch_begin)
  window_info.epoch_end_formatted = format_utils.formatEpochShort(window_info.epoch_begin, window_info.epoch_end, window_info.epoch_end)
end

print(json.encode(window_info))
