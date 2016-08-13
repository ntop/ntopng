--
-- (C) 2016 - ntop.org
--

local trace_hk = false

if(trace_hk) then print("Initialized script useractivity.lua\n") end

-- ########################################################

function getFlowKey(f)
   return(f["cli.ip"]..":"..f["cli.port"].." <-> " ..f["srv.ip"]..":"..f["srv.port"])
end

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function splitProto(proto)
   return unpack(proto:split("."))
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
   local proto = flow.getNdpiProto()
   local master, sub = splitProto(proto)
   
   if(master == "BitTorrent") then
      flow.setActivityFilter(filter.RollingMean, profile.FileSharing)
   elseif (master == "OpenVPN") then
      flow.setActivityFilter(filter.RollingMean, profile.VPN)
   elseif (master == "IMAPS" or master == "IMAP") then
      flow.setActivityFilter(filter.CommandSequence, profile.MailSync)
   elseif (master == "POP3") then
      flow.setActivityFilter(filter.None, profile.MailSync)
   elseif (master == "SMPT" or master == "SMPTS") then
      flow.setActivityFilter(filter.None, profile.MailSend)
   elseif (master == "HTTP" or master == "HTTPS" or "SSL") then
      flow.setActivityFilter(filter.Web, profile.Web)
   elseif (master == "DNS") then
      flow.setActivityFilter(filter.None, profile.None)
   else
      flow.setActivityFilter(filter.None, profile.Other)
   end

   if(trace_hk) then
      f = flow.dump() 
      print("flowProtocolDetected(".. getFlowKey(f)..") = "..f["proto.ndpi"].."\n")
    end
end
