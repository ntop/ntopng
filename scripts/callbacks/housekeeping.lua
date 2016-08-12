--
-- (C) 2016 - ntop.org
--

local trace_hk = false
local trace_hk_imaps = false

if(trace_hk) then print("Initialized script housekeeping.lua\n") end

-- ########################################################

function getFlowKey(f)
   return(f["cli.ip"]..":"..f["cli.port"].." <-> " ..f["srv.ip"]..":"..f["srv.port"])
end

function timeToString(ts)
   return os.date('%Y-%m-%d %H:%M:%S', ts)
end

-- ########################################################

function flowUpdate()
   if(trace_hk) then print("flowUpdate()\n") end
   -- print("=>"..flow.getNdpiProto().."@"..flow.getProfileId().."\n")
 -- flow.setProfileId(os.time())
end

function flowCreate()
   if(trace_hk) then print("flowCreate()\n") end
end

function flowDelete()
   if(trace_hk) then print("flowDelete()\n") end
end

function flowProtocolDetected()
   if(trace_hk) then
      f = flow.dump() 
      print("flowProtocolDetected(".. getFlowKey(f)..") = "..f["proto.ndpi"].."\n")
    end
end

function flowImapsCommand(reqTime, reqBytes, respCount, respBytes, srvWaited)
    if trace_hk_imaps then
        io.write(" <IMAPS> "..flow.getServerName().." - "..timeToString(reqTime)..(srvWaited and " Y" or " N").." req="..reqBytes.." B count="..respCount.." bytes="..respBytes.."\n")
    end
end
