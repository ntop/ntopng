--
-- (C) 2013-21 - ntop.org
--
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path

local recipients = require "recipients"
local periodicity = 3

local now = os.time()

-- Do the actual processing
recipients.process_notifications(now, now + periodicity --[[ deadline --]], periodicity)
