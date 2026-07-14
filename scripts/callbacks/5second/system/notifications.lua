--
-- (C) 2013-26 - ntop.org
--
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

local recipients = require "recipients"
local periodicity = 3

-- io.write("notifications.lua ["..os.time().."]["..periodicity.."]\n")

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 60 / periodicity
local sleep_duration = periodicity * 1000

for i=1,num_runs do
   local now = os.time()

   if(ntop.isShuttingDown()) then break end
   
   -- Do the actual processing
   local num_processed = recipients.process_notifications(now, now + periodicity --[[ deadline --]], periodicity)

   if(num_processed == 0) then
      -- Sleep if thre's nothing to do      
      ntop.msleep(sleep_duration)
   end
end
