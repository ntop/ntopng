--
-- (C) 2013-20 - ntop.org
--
-- This script is used to perform activities that are low
-- priority with respect to second.lua but that require
-- near realtime execution.
-- This script is executed every 3 seconds
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

require "lua_utils"
local recipients = require "recipients"
local recipients_instance = recipients:create()
local periodicity = 3

while not ntop.isShutdown() do
   -- Process notifications every three seconds.
   local start_ms = ntop.gettimemsec()

   local now = os.time()
   recipients_instance:process_notifications(now, now + periodicity --[[ deadline --]], periodicity)

   -- Sleep for a time which is three seconds minus the amount of time spent processing notifications
   local end_ms = ntop.gettimemsec()
   local nap_ms = (periodicity - (end_ms - start_ms)) * 1000
   if nap_ms < 0 then nap_ms = 0 end

   ntop.msleep(nap_ms)
end
