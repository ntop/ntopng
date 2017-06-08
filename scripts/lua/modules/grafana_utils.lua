--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

json = require("dkjson")

function isCORSpreflight()
   if _SERVER["REQUEST_METHOD"] == "OPTIONS"
     and isEmptyString(_SERVER["Access-Control-Request-Method"]) == false
     and isEmptyString(_SERVER["Access-Control-Request-Headers"]) == false then
	return true
   end
   return false
end

function processCORSpreflight()
   local corsh = {}
   corsh["Access-Control-Allow-Origin"] = "*"
   corsh["Access-Control-Allow-Methods"] = "POST, OPTIONS"
   corsh["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
   sendHTTPHeader('text/plain', nil, corsh)
end

function toEpoch(datestring)
   -- parse
   local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%p])"
   local year, month, day, hour, minute, seconds, tzoffset = datestring:match(pattern)
   assert(tzoffset == "Z")
   local timestamp = os.time( { year=year, month=month, day=day, hour=hour, min=minute, sec=seconds })

   -- convert to localtime
   -- for this conversion we need precalculated value "zone_diff"
   local d1 = os.date("*t",  timestamp)
   local d2 = os.date("!*t", timestamp)
   d1.isdst = false
   local zone_diff = os.difftime(os.time(d1), os.time(d2))

   -- now we can perform the conversion (dt -> ux_time):
   timestamp = timestamp + zone_diff

   -- tprint({datestring=datestring, year=year, month=month, day=day, hour=hour, minute=minute, seconds=seconds, tzoffset=tzoffset, timestamp=timestamp})

   return timestamp
end

function toSeries(jsonrrd)
   local res = {}

   for _, rrd in pairs(jsonrrd) do
      local datapoints = {}

      for _, point in ipairs(rrd["values"]) do
	 local instant = point[1]
	 local val     = point[2]
	 datapoints[#datapoints + 1] = {val, instant*1000}
      end

      res[#res + 1] = {target = rrd["key"], datapoints = datapoints}
   end

   return res
end

if _GRAFANA == nil then
   _GRAFANA = {}
end

if not isEmptyString(_GRAFANA["payload"]) then
   _GRAFANA["payload"] = json.decode(_GRAFANA["payload"])
else
   _GRAFANA["payload"] = {}
end
