--
-- (C) 2016 - ntop.org
--

local trace_hk = false

if(trace_hk) then print("Initialized script housekeeping.lua\n") end

function flowUpdate(f)
   if(trace_hk) then print("flowUpdate()\n") end
   -- print("=>"..flow.getNdpiProto().."@"..flow.getProfileId().."\n")
 -- flow.setProfileId(os.time())
end

function flowCreate(f)
   if(trace_hk) then print("flowCreate()\n") end
end

function flowDelete(f)
   if(trace_hk) then print("flowDelete()\n") end
end
