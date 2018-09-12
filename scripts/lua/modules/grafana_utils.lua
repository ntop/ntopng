--
-- (C) 2013-18 - ntop.org
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

function toSeries(jsonrrd, res, label)
   for _, rrd in pairs(jsonrrd.series) do
      local datapoints = {}
      local instant = jsonrrd.start
      local scale = 1

      if rrd["label"]:find("bytes") then
	 -- grafana rates are returned in bits an not bytes per second
	 scale = 8
      end

      for _, point in ipairs(rrd["data"]) do
	 local val     = point
	 datapoints[#datapoints + 1] = {val * scale, instant * 1000}
	 instant = instant + jsonrrd.step
      end

      local target = rrd.tags.protocol or rrd.tags.category or rrd["label"]
      if label then target = target.." "..label end
      res[#res + 1] = {target = target, datapoints = datapoints}
   end

end

if _POST == nil then
   _POST = {}
end

if not isEmptyString(_POST["payload"]) then
   _POST["payload"] = json.decode(_POST["payload"])
else
   _POST["payload"] = {}
end
