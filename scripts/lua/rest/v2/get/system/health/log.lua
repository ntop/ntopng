--
-- (C) 2013-26 - ntop.org
--
-- Health > System Status: the last lines of the ntopng log (raw text, newest first)
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

-- Not on OEM builds, as the old page; -1: the system interface
if not ntop.isAllowedInterface(-1) or ntop.getInfo(false).oem then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- Same lines as the old System Status page
local MAX_LINES = 33
local res = {}

for i = 0, MAX_LINES - 1 do
   local msg = ntop.listIndexCache("ntopng.trace", i)
   if msg ~= nil then
      res[#res + 1] = msg
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
