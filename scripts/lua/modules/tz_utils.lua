--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()
local os_utils = require("os_utils")
local tz_utils = {}

function tz_utils.ListTimeZones()
   local tz_file = os_utils.fixPath(dirs.httpdocsdir.."/other/TimeZones.txt")
   local res = {}

   if ntop.exists(tz_file) then
      for line in io.lines(tz_file) do
	 res[#res + 1] = line
      end
   end

   return res
end

function tz_utils.TimeZone()
   -- currently not portable for WINDOWS
   local f = io.open(os_utils.fixPath("/etc/timezone"), "r")
   local tz
   if f then
      tz = f:read "*l"
      f:close()
   end
   return tz
end

return tz_utils
