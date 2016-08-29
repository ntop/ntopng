--
-- (C) 2016 - ntop.org
--

local trace_hk = false
local profile_activity_match
local media_activity_defaults = {filter.SMA, --[[min bytes]] 500, --[[min samples]]1, --[[bound time]]500, --[[sustain time]]4000}
local web_activity_defaults = {filter.Web}
local default_activity_parameters = {filter.All, true}

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

function flowUpdate()
   if(trace_hk) then print("flowUpdate()\n") end
   -- print("=>"..flow.getNdpiProto().."@"..flow.getProfileId().."\n")
 -- flow.setProfileId(os.time())

   local proto = flow.getNdpiProto()
   local master, sub = splitProto(proto)

   if master == "HTTP" then
      local contentType = flow.getHTTPContentType()
      if contentType then
         if flow.getProfileId() ~= profile.Media then
            local mDetected = false
            
            -- Try to detect a media type
            for i=1, #media_activity_mime_types do
               if contentType:starts(media_activity_mime_types[i]) then
                  flow.setActivityFilter(profile.Media, unpack(media_activity_defaults))
                  mDetected = true
                  break
               end
            end

            -- Try to detect a web type
            if not mDetected and flow.getActivityFilterId() ~= filter.All then
               for i=1, #web_activity_mime_types do
                  if contentType:starts(web_activity_mime_types[i]) then
                     -- Be always active
                     flow.setActivityFilter(profile.Web, filter.All, true)
                     break
                  end
               end
            end
         end
      end
   end
end

-- ########################################################

function flowCreate()
   if(trace_hk) then print("flowCreate()\n") end
end

-- ########################################################

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
         "YouTube",
         "NetFlix",
         "LastFM",

         -- Media types
         "AVI",
         "Flash",
         "OggVorbis",
         "MPEG",
         "MPEG_TS",
         "QuickTime",
         "RealMedia",
         "WindowsMedia",
         "WebM"
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
      ["defaults"] = {filter.CommandSequence, false, 200, 3000, 1},
      ["protos"] = {
         "IMAP",
         "IMAPS"
      }
   },{
      ["profile"] = profile.MailSync,
      ["defaults"] = default_activity_parameters,
      ["protos"] = {
         "POP3",
         "POPS"
      }
   },

   -- MailSend profile
   {
      ["profile"] = profile.MailSend,
      ["defaults"] = default_activity_parameters,
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
      ["defaults"] = default_activity_parameters,
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
         "Twitter",
         "Viber",
         "Slack",
         "Weibo"
      }
   },

   -- Game profile
   {
      ["profile"] = profile.Game,
      ["defaults"] = default_activity_parameters,
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

   -- Web profile
   {
      ["profile"] = profile.Web,
      ["defaults"] = web_activity_defaults,
      ["protos"] = {
         "HTTP",
         "HTTPS"
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

function flowProtocolDetected()
   local proto = flow.getNdpiProto()
   local master, sub = splitProto(proto)
   local srv = flow.getServerName()
   local matched = nil

   if master ~= "DNS" then
   
-- BEGIN Particular protocols
      if sub == "Facebook" then
         local config
         if master == "HTTP" then
            -- mark as background traffic
            config = {filter.All, false}
         else
            config = {filter.Interflow, 2, 400, 3}
         end
         matched = {["profile"]=profile.Facebook, ["config"]=config}
      elseif sub == "YouTube" and not srv:ends("googlevideo.com") then
         -- just normal web traffic
         matched = {["profile"]=profile.Web, ["config"]=web_activity_defaults}
-- END Particular protocols      
      else
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
                  break
               end
            end

            if matched then break end
         end
      end

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
