--
-- (C) 2016-18 - ntop.org
--

--
-- NOTE: You should *NOT* delete/edit this file. Create a new file in this directory instead.
--

-- ########################################################
--
--    < Lua Virtual Machine - periodic >
--
-- The callbacks listed below are executed periodically.
-- Usually these callbacks cannot modify internal objects status because of
-- missing thread synchronization logic.
--
-- ########################################################

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require("lua_utils")

-- Enable debug here
local trace_enabled = false

local callbacks = {}

-- ########################################################

--
-- This callback is called periodically for all active flows
-- Add here housekeeping of periodic activities you want to
-- perform in a flow.
-- Flow callbacks can be accesed via "flow" register.
--
function callbacks.flowUpdate()
   if(trace_enabled) then print("flowUpdate()\n") end
end

--
-- This callback is called once, when a new flow is deleted
-- Flow callbacks can be accesed via "flow" register.
--
function callbacks.flowDelete()
   if(trace_enabled) then print("flowDelete()\n") end
end

-- ########################################################

return callbacks 
