--
-- (C) 2016-17 - ntop.org
--

-- Enable tracings here
local trace_hk = false

local default_activity_parameters = {filter.SMA}
local media_activity_defaults = {filter.SMA, --[[min bytes]] 500, --[[min samples]]1, --[[bound time]]500, --[[sustain time]]4000}
local web_activity_defaults = {filter.Web}

if(trace_hk) then print("Initialized script useractivity.lua\n") end

-- ########################################################

-- TODO expose and use nDPI types
local media_activity_mime_types = {
   "audio/",
   "video/",
   "application/x-shockwave-flash"
}

local web_activity_mime_types = {
   "text/",
   "application/javascript",
   "application/x-javascript",
   "application/ecmascript"
}

-- ########################################################

function getFilterConfiguration(flow, master, sub)
   local category = flow.getNdpiCategory()
   local srv = flow.getServerName()
   local matched = nil

   -- Particular protocols detection - phase 1
   if sub == "YouTube" then
      if srv:ends("googlevideo.com") then
         matched = {["profile"]='Media', ["config"]={filter.All, true}}
      else
         matched = {["profile"]='Media', ["config"]=web_activity_defaults}
      end
   elseif master == "HTTP" then
      local contentType = flow.getHTTPContentType()
      if contentType then
         if flow.getProfileId() ~= profile.Media then
            -- Try to detect a media type
            for i=1, #media_activity_mime_types do
               if contentType:starts(media_activity_mime_types[i]) then
                  matched = {["profile"]='Media', ["config"]=media_activity_defaults}
                  break
               end
            end

            -- Try to detect a web type
            if not matched and flow.getActivityFilterId() ~= filter.All then
               for i=1, #web_activity_mime_types do
                  if contentType:starts(web_activity_mime_types[i]) then
                     -- Be always active
                     matched = {["profile"]='Web', ["config"]={filter.All, true}}
                     break
                  end
               end
            end
         end
      end
   elseif sub == "Twitter" then
      matched = {["profile"]='SocialNetwork', ["config"]={filter.Interflow, 3, 200}}
   elseif sub == "Facebook" then
      matched = {["profile"]='SocialNetwork', ["config"]={filter.Interflow, 3, 600, -1, true}}
   elseif sub == "OpenVPN" then
      matched = {["profile"]='VPN', ["config"]={filter.SMA, 150, 3, 3000, 2000}}
   elseif sub == "Hotmail" and category == "EmailSync" then
      matched = {["profile"]='MailSync', ["config"]={filter.CommandSequence, true, 15000, 3000, 7}}
   end

   -- Category match
   if not matched then
      if category == "SocialNetwork" or category == "Web" then
         matched = {["profile"]='Web', ["config"]=web_activity_defaults}
      elseif category == "Collaborative" then
         matched = {["profile"]='Web', ["config"]={filter.All, false}}
      elseif category == "VoIP" then
         matched = {["profile"]='Media', ["config"]={filter.All, false}}
      elseif category == "Media" then
         matched = {["profile"]='Media', ["config"]=media_activity_defaults}
      elseif category == "VPN" then
         matched = {["profile"]='VPN', ["config"]={filter.SMA}}
      elseif category == "EmailSync" then
         matched = {["profile"]='MailSync', ["config"]={filter.CommandSequence, false, 200, 3000}}
      elseif category == "MailSend" then
         matched = {["profile"]='MailSend', ["config"]={filter.All, true}}
      elseif category == "FileTransfer" then
         matched = {["profile"]='FileTransfer', ["config"]={filter.SMA}}
      elseif category == "P2P" then
         matched = {["profile"]='FileSharing', ["config"]={filter.SMA, 300, 3, 4000, 3000}}
      elseif category == "Chat" then
         matched = {["profile"]='Chat', ["config"]={filter.All, true}}
      elseif category == "Game" then
         matched = {["profile"]='Game', ["config"]={filter.All, true}}
      elseif category == "RemoteAccess" then
         matched = {["profile"]='RemoteControl', ["config"]={filter.SMA, 20}}
      end
   end

   -- Particular protocols detection - phase 2
   if not matched then
      if master == "SSL" or master == "SSL_No_Cert" then
         -- Note: web filter will possibly update the flow to the Web profile
         matched = {["profile"]='Other', ["config"]={filter.Web}}
      end
   end

   -- Fallback
   if not matched then
      matched = {["profile"]='Other', ["config"]=default_activity_parameters}
   end

   return matched
end

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

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end


function string.search(String,Search,Start)
   return string.find(String, Search, Start or 1, false)
end

function splitProto(proto)
   return unpack(proto:split("."))
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
   local proto = flow.getNdpiProto()
   local master, sub = splitProto(proto)

   if master ~= "DNS" then
      local matched = getFilterConfiguration(flow, master, sub)

      flow.setActivityFilter(profile[matched.profile], unpack(matched.config))

      if(trace_hk) then
         f = flow.dump()
         print("flowProtocolDetected(".. getFlowKey(f)..") = "..f["proto.ndpi"].." ["..(matched.profile).."]\n")
      end
   end
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
   if(trace_hk) then print("flowUpdate()\n") end
end
