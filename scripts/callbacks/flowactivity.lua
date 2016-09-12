--
-- (C) 2016 - ntop.org
--

-- Enable tracings here
local trace_hk = false

local profile_activity_match
local default_activity_parameters = {filter.SMA}
local media_activity_defaults = {filter.SMA, --[[min bytes]] 500, --[[min samples]]1, --[[bound time]]500, --[[sustain time]]4000}
local web_activity_defaults = {filter.Web}

if(trace_hk) then print("Initialized script useractivity.lua\n") end

-- ########################################################

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

-- ########################################################

function splitProto(proto)
   return unpack(proto:split("."))
end

-- ########################################################

--
-- This callback is called periodically for all active flows
-- Add here housekeeping of periodic activities you want to
-- perform in a flow
--
function flowUpdate()
   if(trace_hk) then print("flowUpdate()\n") end
end

-- ########################################################

--
-- This callback is called once, when a new flow is created
--
function flowCreate()
   if(trace_hk) then print("flowCreate()\n") end
end

-- ########################################################

--
-- This callback is called once, when a new flow is deleted
--
function flowDelete()
   if(trace_hk) then print("flowDelete()\n") end
end

-- ########################################################

-- These are matched top-down, so order is important
local profile_activity_match = {
   -- Media profile
   {
      ["profile"] = profile.Media,
      ["defaults"] = {filter.All, false},
      ["protos"] = {
         "MGCP",
         "RTCP",
         "RTSP",
         "SIP",
         "H323",
         "Megaco",
         "CiscoSkinny"
      }
   },{
      ["profile"] = profile.Media,
      ["defaults"] = media_activity_defaults,
      ["protos"] = {
         "RTMP",
         "RTP",
         "PPLive",
         "PPStream",
         "Tvants",
         "TVUplayer",
         "Zattoo",
         "IceCast",
         "ShoutCast",
         "Sopcast",
         "QQLive",
         "QuickPlay",
         "Vevo",
         "IAX",
         "Webex",
         "WhatsAppVoice",
         "KakaoTalk_Voice",
         "TruPhone",
         "SPOTIFY",
         "Pandora",
         "Deezer",
         "Twitch",
         "NetFlix",
         "LastFM"
      }
   },

   -- VPN profile
   {
      ["profile"] = profile.VPN,
      ["defaults"] = {filter.SMA},
      ["protos"] = {
         ["OpenVPN"] = {filter.SMA, 150, 3, 3000, 2000},
         "CiscoVPN",
         "PPTP",
         "HotspotShield"
      }
   },

   -- MailSync profile
   {
      ["profile"] = profile.MailSync,
      ["defaults"] = {filter.CommandSequence, false, 200, 3000},
      ["protos"] = {
         ["Hotmail"] = {filter.CommandSequence, true, 15000, 3000, 7},
         "IMAP",
         "IMAPS"
      }
   },{
      ["profile"] = profile.MailSync,
      ["defaults"] = {filter.All, true},
      ["protos"] = {
         "POP3",
         "POPS"
      }
   },

   -- MailSend profile
   {
      ["profile"] = profile.MailSend,
      ["defaults"] = {filter.All, true},
      ["protos"] = {
         "SMTP",
         "SMTPS"
      }
   },

   -- FileTransfer profile
   {
      ["profile"] = profile.FileTransfer,
      ["defaults"] = {filter.SMA},
      ["protos"] = {
         ["FTP_CONTROL"] = {filter.All, false},
         ["HTTP_Application_ActiveSync"] = {filter.All, false},
         "FTP_DATA",
         "Direct_Download_Link",
         "AFP",
         "Dropbox",                          -- TODO implement proper background detection
         "NFS",
         "SMB",
         "UbuntuONE",
         "MS_OneDrive",
         "RSYNC",
         "TFTP"
      }
   },

   -- FileSharing profile
   {
      ["profile"] = profile.FileSharing,
      ["defaults"] = {filter.SMA, 300, 3, 4000, 3000},
      ["protos"] = {
         "BitTorrent",
         "Gnutella",
         "AppleJuice",
         "DirectConnect",
         "eDonkey",
         "FastTrack",
         "Filetopia",
         "iMESH",
         "OpenFT",
         "Pando_Media_Booster",
         "Soulseek",
         "Stealthnet",
         "Thunder"
      }
   },

   -- Chat profile
   {
      ["profile"] = profile.Chat,
      ["defaults"] = {filter.All, true},
      ["protos"] = {
         "GoogleHangout",
         "IRC",
         "Unencryped_Jabber",
         "Meebo",
         "MSN",
         "Oscar",
         "QQ",
         "Skype",
         "TeamSpeak",
         "Telegram",
         "Viber",
         "Slack",
         "Weibo"
      }
   },

   -- Game profile
   {
      ["profile"] = profile.Game,
      ["defaults"] = {filter.All, true},
      ["protos"] = {
         "Dofus",
         "BattleField",
         "Armagetron",
         "Florensia",
         "Guildwars",
         "HalfLife2",
         "MapleStory",
         "Quake",
         "Starcraft",
         "Warcraft3",
         "WorldOfKungFu",
         "WorldOfWarcraft",
         "Xbox"
      }
   },

   -- RemoteControl profile
   {
      ["profile"] = profile.RemoteControl,
      ["defaults"] = {filter.SMA, 20},
      ["protos"] = {
         "PcAnywhere",
         "RDP",
         "SSH",
         "TeamViewer",
         "Telnet",
         "VNC",
         "XDMCP"
      }
   },

   -- SocialNetwork profile
   {
      ["profile"] = profile.SocialNetwork,
      ["defaults"] = {filter.Interflow},
      ["protos"] = {
         ["Twitter"] = {filter.Interflow, 3, 200},
         ["Facebook"] = {filter.Interflow, 3, 600, -1, true}
      }
   },

   -- Web profile
   {
      ["profile"] = profile.Web,
      ["defaults"] = web_activity_defaults,
      ["protos"] = {
         "HTTP",
         "HTTPS",
         "YouTube"
      }
   },

   -- Other profile
   {
      ["profile"] = profile.Other,
      -- Note: filter.Web will possibly update the flow to Web profile
      ["defaults"] = {filter.Web},
      ["protos"] = {
         "SSL",
         "SSL_No_Cert"
      }
   }
}

-- ########################################################

--
-- This callback is called once as soon as the flow application
--  protocol has been identified by the ntopng core
--
function flowProtocolDetected()
   local proto = flow.getNdpiProto()
   local master, sub = splitProto(proto)
   local srv = flow.getServerName()

   if master ~= "DNS" then
      local matched = nil

      -- Particular protocols detection
      if sub == "YouTube" and srv:ends("googlevideo.com") then
         matched = {["profile"]=profile.Media, ["config"]={filter.All, true}}
      elseif master == "HTTP" then
         local contentType = flow.getHTTPContentType()
         if contentType then
            if flow.getProfileId() ~= profile.Media then
               -- Try to detect a media type
               for i=1, #media_activity_mime_types do
                  if contentType:starts(media_activity_mime_types[i]) then
                     matched = {["profile"]=profile.Media, ["config"]=media_activity_defaults}
                     break
                  end
               end

               -- Try to detect a web type
               if not matched and flow.getActivityFilterId() ~= filter.All then
                  for i=1, #web_activity_mime_types do
                     if contentType:starts(web_activity_mime_types[i]) then
                        -- Be always active
                        matched = {["profile"]=profile.Web, ["config"]={filter.All, true}}
                        break
                     end
                  end
               end
            end
         end
      end

      -- Plain detection
      if not matched then
         for i=1, #profile_activity_match do
            local pamatch = profile_activity_match[i]
            local profile = pamatch["profile"]
            local protos = pamatch["protos"]

            for k,v in pairs(protos) do
               local matchproto
               local config = nil

               if type(v) == "table" then
                  matchproto = k
                  config = v
               else
                  matchproto = v
               end

               if matchproto == master or matchproto == sub then
                  matched = {["profile"]=profile, ["proto"]=matchproto, ["config"]=config, ["defaults"]=pamatch["defaults"]}
                  -- prefer subprotocols match within the same profile
                  if matchproto == sub then
                     break
                  end
               end
            end

            if matched then break end
         end
      end

      -- Update Flow status
      if matched then
         local params = matched.config or matched.defaults
         flow.setActivityFilter(matched.profile, unpack(params))
      else
         flow.setActivityFilter(profile.Other, unpack(default_activity_parameters))
      end

      if(trace_hk) then
         f = flow.dump()
         print("flowProtocolDetected(".. getFlowKey(f)..") = "..f["proto.ndpi"].."\n")
      end
   end
end
