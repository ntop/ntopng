--
-- (C) 2013-21 - ntop.org
--
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

local recipients = require "recipients"
local periodicity = 3

-- io.write("notifications.lua ["..os.time().."]["..periodicity.."]\n")

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 30 / periodicity
local sleep_duration = periodicity * 1000

for i=1,num_runs do
   local now = os.time()
   
   -- Do the actual processing
   recipients.process_notifications(now, now + periodicity --[[ deadline --]], periodicity)

   ntop.msleep(sleep_duration)
end
