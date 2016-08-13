--
-- (C) 2016 - ntop.org
--

local trace_hk = false

if(trace_hk) then print("Initialized script useractivity.lua\n") end

-- ########################################################

function getFlowKey(f)
   return(f["cli.ip"]..":"..f["cli.port"].." <-> " ..f["srv.ip"]..":"..f["srv.port"])
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
   -- ogni profilo ha: up, down, background
   -- se il filtro torna false, allora background
   -- altrimenti, si aggiornano i contatori dell'host
   local proto = flow
   
   if(proto == "Torrent") then
      flow.setActivityFilter(filter.RollingMean, profile.FileSharing, 100, 20)
   elseif (proto == "OpenVpn") then
      flow.setActivityFilter(filter.RollingMean, profile.VPN, 100, 20)
   elseif (proto == "IMAPS" or proto == "IMAP") then
      flow.setActivityFilter(filter.CommandSequence, profile.MailSync, 400)
   elseif (proto == "POP3") then
      flow.setActivityFilter(filter.None, profile.MailSync)
   elseif (proto == "SMPT" or proto == "SMPTS") then
      flow.setActivityFilter(filter.None, profile.MailSend)
   elseif (proto == "HTTP" or proto == "HTTPS") then
      flow.setActivityFilter(filter.Web, profile.Web)
   else
      flow.setActivityFilter(filter.None, profile.Other)
   end

   if(trace_hk) then
      f = flow.dump() 
      print("flowProtocolDetected(".. getFlowKey(f)..") = "..f["proto.ndpi"].."\n")
    end
   
   -- TODO just test
   --~ flow.setActivity(1, 1500)
end
