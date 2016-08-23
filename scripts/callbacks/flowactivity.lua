--
-- (C) 2016 - ntop.org
--

local trace_hk = false
local profile_activity_match = {}

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

-- ########################################################

function splitProto(proto)
   return unpack(proto:split("."))
end

-- ########################################################

function flowUpdate()
   if(trace_hk) then print("flowUpdate()\n") end
   -- print("=>"..flow.getNdpiProto().."@"..flow.getProfileId().."\n")
 -- flow.setProfileId(os.time())
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

function initProfileMatch()
   -- These are matched top-down, so order is important

   -- Media profile
   table.insert(profile_activity_match, {
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
   })
   table.insert(profile_activity_match, {
      ["profile"] = profile.Media,
      ["defaults"] = {filter.SMA},
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
   })

   -- VPN profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.VPN,
      --~ ["defaults"] = {profile.VPN, filter.WMA, 140, 3, 1000.0, 1}
      ["defaults"] = {filter.SMA},
      ["protos"] = {
         ["OpenVPN"] = {filter.SMA, 150, 3, 3000, 2000},
         "CiscoVPN",
         "PPTP",
         "HotspotShield"
      }
   })

   -- MailSync profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.MailSync,
      ["defaults"] = {filter.CommandSequence, false, 200, 3000, 1},
      ["protos"] = {
         "IMAP",
         "IMAPS"
      }
   })
   table.insert(profile_activity_match, {
      ["profile"] = profile.MailSync,
      ["defaults"] = {},
      ["protos"] = {
         "POP3",
         "POPS"
      }
   })

   -- MailSend profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.MailSend,
      ["defaults"] = {},
      ["protos"] = {
         "SMTP",
         "SMTPS"
      }
   })

   -- FileTransfer profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.FileTransfer,
      ["defaults"] = {filter.SMA},
      ["protos"] = {
         ["FTP_CONTROL"] = {filter.All, false},
         ["HTTP_Application_ActiveSync"] = {filter.All, false},
         "FTP_DATA",
         "Direct_Download_Link",
         "AFP",
         "Dropbox",                          -- TODO implement proper background detection
         "NFS",                              -- TODO implement proper background detection
         "SMB",                              -- TODO implement proper background detection
         "UbuntuONE",
         "MS_OneDrive",
         "RSYNC",
         "TFTP"                              -- TODO control or data?
      }
   })

   -- FileSharing profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.FileSharing,
      ["defaults"] = {filter.SMA, 300, 2, 4000, 3000},
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
   })

   -- App profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.App,
      ["defaults"] = {},
      ["protos"] = {
         "Crossfire",
         "Corba",
         "DCE_RPC",
         "DRDA",
         "Git",
         "Kerberos",
         "Syslog",
         "Collectd",
         "RemoteScan",
         "Office365",
         "Instagram",
         "Waze",
         "Snapchat"
      }
   })

   -- Chat profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.Chat,
      ["defaults"] = {},
      ["protos"] = {
         "GoogleHangout",
         "IRC",
         "Unencryped_Jabber",
         "Meebo",
         "MSN",
         "Oscar",
         "QQ",
         "Skype",                            -- TODO chat or media?
         "TeamSpeak",                        -- TODO chat or media?
         "Telegram",
         "TWITTER",
         "VIBER",
         "YAHOO",                            -- TODO chat or media?
         "Slack",
         "Weibo"
      }
   })

   -- Game profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.Game,
      ["defaults"] = {},
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
         "Steam",                             -- TODO chat, download ??
         "Warcraft3",
         "WorldOfKungFu",
         "WorldOfWarcraft",
         "Xbox"
      }
   })

   -- RemoteControl profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.RemoteControl,
      ["defaults"] = {filter.SMA},            -- TODO refine
      ["protos"] = {
         "PcAnywhere",
         "RDP",
         "SSH",                               -- TODO detect file transfers over SSH
         "TeamViewer",
         "Telnet",
         "VNC",
         "XDMCP"
      }
   })

   -- Web profile
   table.insert(profile_activity_match, {
      ["profile"] = profile.Web,
      ["defaults"] = {filter.Web},
      ["protos"] = {
         "Facebook",
         "HTTP",
         "HTTPS",
         "SSL",
         "SSL_No_Cert"
      }
   })
end

-- ########################################################

function flowProtocolDetected()
   local proto = flow.getNdpiProto()
   local master, sub = splitProto(proto)
   local srv = flow.getServerName()
   local matched = nil

   if #profile_activity_match == 0 then initProfileMatch() end

   if master ~= "DNS" then
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

      if matched then
         local params = matched.config or matched.defaults
         flow.setActivityFilter(matched.profile, unpack(params))
      else
         flow.setActivityFilter(profile.Other)
      end

      if(trace_hk) then
         f = flow.dump() 
         print("flowProtocolDetected(".. getFlowKey(f)..") = "..f["proto.ndpi"].."\n")
      end
   end
end
