--
-- (C) 2016-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require("lua_utils")

-- Enable tracings here
local trace_hk = false

-- ########################################################

function getFlowKey(f)
   return(f["cli.ip"]..":"..f["cli.port"].." <-> " ..f["srv.ip"]..":"..f["srv.port"])
end

-- ########################################################
--
--    < Lua Virtual Machine - main >
--
-- The callbacks listed below are executed in the main ntopng thread, so
-- you can call most of the Flow functions without any synchronization troubles.
--
-- ########################################################

--
-- This callback is called once, when a new flow is created
--
function flowCreate()
   if(trace_hk) then print("flowCreate()\n") end
end

--
-- This callback is called once, when a new flow is deleted
--
function flowDelete()
   if(trace_hk) then print("flowDelete()\n") end
end

--
-- This callback is called any time some flow status, affecting activity
-- detection logic, changes. This happens, for example, when flow protocol
-- is detected.
--
function flowProtocolDetected()
   if(trace_hk) then print("flowProtocolDetected()\n") end
end

-- ########################################################
--
--    < Lua Virtual Machine - periodic >
--
-- The callbacks listed below are executed periodically, NOT in the main
-- thread. This means that particular care must be taken before accessing
-- Flow state or other main thread related structure.
-- This is the right place to perform more intensive tasks.
--
-- ########################################################

--
-- This callback is called periodically for all active flows
-- Add here housekeeping of periodic activities you want to
-- perform in a flow
--
function flowUpdate()
   local v
   
   if(trace_hk) then print("flowUpdate()\n") end

end
