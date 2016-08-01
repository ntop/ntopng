--
-- (C) 2016 - ntop.org
--

print("Initialized script housekeeping.lua\n")

function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function split_proto(proto)
  local s = proto:split(".")
  local res = {}

  res["main"] = s[1]
  res["other"] = s[2]

  return res
end

-- Protocols (aggregated as well)
WEB_INDICATORS_PROTOS = {
  "Cloudflare"
}
-- Sites
WEB_INDICATORS_S = {
  "www.googleadservices.com",
  "d.turn.com",                               -- analytics
  "statse.webtrendslive.com",                 -- analytics
  "hm.webtrends.com",                         -- Microsoft analytics
  "fonts.googleapis.com",                     -- Google fonts
  "fonts.gstatic.com",                        -- Google fonts
  "www.google-analytics.com",                 -- Google analytics
  "ajax.googleapis.com",                      -- Google apis
  "cdn.sstatic.net",                          -- content hosting
  "engine.adzerk.net",                        -- content hosting
  "static.adzerk.net",                        -- content hosting
  "pixel.quantserve.com",                     -- analytics
  "edge.quantserve.com",                      -- analytics
  "srv.juiceadv.com"                          -- advertising
}
-- Sites with patterns
WEB_INDICATORS_P = {
  "^.*%.imgur%.com$",                         -- CloudFlare
  "^.*%.cloudflare.com$",                     -- CloudFlare
  "^.*%.popads%.net$",                        -- advertising popads
  "^.*%.scorecardresearch%.com$",             -- analytics scorecardresearch
  "^.*%.gstatic%.com$",                       -- Google gstatic content hosting

  "^.*%.duckduckgo.com$",                     -- DuckDuckGo search engine
  "^.*%.yahoo.net$",                          -- Yahoo
  "^.*%.forumfree%.[a-zA-Z]+$",               -- forumfree
  "^.*%.forumcommunity%.[a-zA-Z]+$",          -- forumcommunity
  "^.*%.altervista%.[a-zA-Z]+$",              -- altervista
  "^.*%.stackoverflow.com$",                  -- StackOverflow
  "^.*%.github.com$"                          -- Github
}

VIDEO_HOST_URLS_P = {
  "^.*%.oloadcdn%.net$",                      -- Openload
  "^.*%.googlevideo.com$",                    -- GoogleVideo
  "^video%-cdg2%-1%.xx%.fbcdn%.net$"          -- Facebook video
}

-------

function _match_web_flow(proto, server, url)
  if proto ~= "HTTPS" and proto ~= "HTTP" and proto ~= "SSL" then
    return false
  end

  if proto == "HTTP" and not url then
    -- site with no url: assume web
    return true
  end

  for i=1, #WEB_INDICATORS_PROTOS do
    if proto == WEB_INDICATORS_PROTOS[i] then
      return true
    end
  end

  for i=1, #WEB_INDICATORS_S do
    if server == WEB_INDICATORS_S[i] then
      return true
    end
  end

  for i=1, #WEB_INDICATORS_P do
    if server:find(WEB_INDICATORS_P[i]) then
      return true
    end
  end

  return false
end

function match_web_flow(proto, server, url)
  if _match_web_flow(proto, server) then
    flow.setProfileId(PROFILES.web)
    -- TODO propagate on time related flows
    return true
  end
  return false
end

function match_vpn_flow(proto, server, cert, hasStart)
  -- TODO better detection (see FB 31.13.86.2 SSL)
  if proto == "OpenVpn" or (proto == "SSL" and hasStart and not cert) then
    flow.setProfileId(PROFILES.vpn)
    return true
  end

  return false
end

function match_video_flow(proto, server)
  for i=1, #VIDEO_HOST_URLS_P do
    if server:find(VIDEO_HOST_URLS_P[i]) then
      flow.setProfileId(PROFILES.video)
      return true
    end
  end

  -- TODO HTTP content type

  return false
end

function match_mail_flow(proto, server)
  local master = split_proto(proto).main

  if master == "IMAP" or master == "IMAPS" or master == "POP3" then
    flow.setProfileId(PROFILES["mail.recv"])
    return true
  end

  if master == "SMTP" or master == "SMTPS" then
    flow.setProfileId(PROFILES["mail.send"])
    return true
  end

  return false
end

-------

function flowUpdate()
  local profile = flow.getProfileId()

  -- debug: to see unmatched flows
  if (profile == PROFILES.other) then
    print("\t"..flow.getNdpiProto().." "..flow.getServerName().."\n")
  end
end

function flowDetect()
  local proto = flow.getNdpiProto()
  local srv = flow.getServerName()

  -- rules
  local matched =
    match_vpn_flow(proto, srv, flow.getSSLCertificate(), flow.hasStart()) or
    match_video_flow(proto, srv) or
    match_mail_flow(proto, srv) or
    match_web_flow(proto, srv, flow.getHTTPUrl())

  print(flow.getFirstSeen().." "..flow.getNdpiProto().."@"..flow.getProfileId().." "..flow.getServerName().."\n")
end

function flowCreate()
  -- print("flowCreate()\n")
end

function flowDelete()
  -- print("flowDelete()\n")
end
