--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local recording_utils = require "recording_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

if not recording_utils.isAvailable() then
  return
end

local epoch_begin = tonumber(_GET["epoch_begin"])
local epoch_end   = tonumber(_GET["epoch_end"])

interface.select(ifname)

local ifstats = interface.getStats()

local result = {}
if recording_utils.isDataAvailable(ifstats.id, epoch_begin, epoch_end) then
  result["available"] = "true"
else
  result["available"] = "false"
end

print(json.encode(result))
