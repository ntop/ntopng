--
-- (C) 2016 - ntop.org
--


-- Enable tracings here
local trace_hk = false

-- ########################################################

function getFlowKey(f)
   return(f["cli.ip"]..":"..f["cli.port"].." <-> " ..f["srv.ip"]..":"..f["srv.port"])
end

-- Print contents of `tbl`, with indentation.
-- You can call it as tprint(mytable)
-- The other two parameters should not be set
function tprint(s, l, i)
   l = (l) or 1000; i = i or "";-- default item limit, indent string
   if (l<1) then io.write("ERROR: Item limit reached.\n"); return l-1 end;
   local ts = type(s);
   if (ts ~= "table") then io.write(i..' '..ts..' '..tostring(s)..'\n'); return l-1 end
   io.write(i..' '..ts..'\n');
   for k,v in pairs(s) do
      local indent = ""

      if(i ~= "") then
	 indent = i .. "."
      end
      indent = indent .. tostring(k)

      l = tprint(v, l, indent);
      if (l < 0) then break end
   end

   return l
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
