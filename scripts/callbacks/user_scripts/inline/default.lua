--
-- (C) 2016-18 - ntop.org
--

--
-- NOTE: You should *NOT* delete/edit this file. Create a new file in this directory instead.
--

-- ########################################################
--
--    < Lua Virtual Machine - inline >
--
-- The callbacks listed below are executed into the ntopng capture thread.
-- These callbacks should do minimal work to avoid dropping packets.
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
-- This callback is called once, when a new flow is created.
-- Flow callbacks can be accesed via "flow" register.
--
function callbacks.flowCreate()
  if(trace_enabled) then print("flowCreate()\n") end
end

--
-- This callback is called whenever the detection of the protocol on the flow is completed
-- Flow callbacks can be accesed via "flow" register.
--
function callbacks.flowProtocolDetected()
   if(trace_enabled) then print("flowProtocolDetected()\n") end
end

-- ########################################################

return callbacks 
