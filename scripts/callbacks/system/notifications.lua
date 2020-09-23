--
-- (C) 2013-20 - ntop.org
--
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"
local recipients = require "recipients"
local periodicity = 3

-- For performace, this script is started in C only one time every hour.
-- A while-loop is implemented inside this script to process notifications
-- every `periodicity` 3 seconds.

while not ntop.isShutdown() and not ntop.isDeadlineApproaching() do
   -- Process notifications every three seconds.
   local start_ms = ntop.gettimemsec()

   local now = os.time()
   recipients.process_notifications(now, now + periodicity --[[ deadline --]], periodicity)

   -- Sleep for a time which is three seconds minus the amount of time spent processing notifications
   local end_ms = ntop.gettimemsec()
   local nap_ms = (periodicity - (end_ms - start_ms)) * 1000
   if nap_ms < 0 then nap_ms = 0 end

   ntop.msleep(nap_ms)
end
