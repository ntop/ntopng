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
  res["sub"] = s[2]

  return res
end

function timeToString(ts)
  return os.date('%Y-%m-%d %H:%M:%S', ts)
end

function printFlow()
  print(timeToString(flow.getFirstSeen()).." "..flow.getNdpiProto().."@"..flow.getProfileId().." "..flow.getServerName().."\n")
end

function setProfile(profile)
  flow.setProfileId(profile)
  printFlow()
end

function bufferedCallback(i, callback)
  local rec = HTTP_FLOW_BUF[i]
  local cur = flow.getRef()
  local rv

  EnterFlow(rec.f)
  rv = callback()
  EnterFlow(cur)
  return rv
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

HTTP_MAX_AGGR_TIME = 15                       -- assume HTTP_MAX_AGGR_TIME < time to GC a flow
LAST_AGGR_TIME = 0
HTTP_FLOW_BUF = {}
LAST_CLEANUP = 0

-------

function _match_web_flow(p1, p2, server, url)
  if p1 ~= "HTTP" and p1 ~= "SSL" then
    return false
  end

  if p1 == "HTTP" and not url then
    -- site with no url: assume web
    return true
  end

  for i=1, #WEB_INDICATORS_PROTOS do
    if p1 == WEB_INDICATORS_PROTOS[i] then
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

function match_web_flow(p1, p2, server, url)
  local matched = false
  local now = flow.getLastSeen()

  if _match_web_flow(p1, p2, server) then
    matched = true
    LAST_AGGR_TIME = now

    -- Aggregate
    for i=1, #HTTP_FLOW_BUF do
      bufferedCallback(i, function () setProfile(PROFILES.web) end)
    end
    HTTP_FLOW_BUF = {}
  else
    if now - LAST_AGGR_TIME <= HTTP_MAX_AGGR_TIME then
      matched = true
    end
  end

  if matched then
    setProfile(PROFILES.web)
    return true
  end

  if p1 == "HTTP" or p1 == "SSL" then
    table.insert(HTTP_FLOW_BUF, {["f"]=flow.getRef(), ["t"]=now})
  end

  return false
end

function clean_web_flows(now)
  for i=#HTTP_FLOW_BUF,1,-1  do
    -- Rmove out of time or with already detected profiles flows
    if now - HTTP_FLOW_BUF[i].t > HTTP_MAX_AGGR_TIME or
      bufferedCallback(i, function () return flow.getProfileId() end) ~= PROFILES.other then
      table.remove(HTTP_FLOW_BUF, i)
    end
  end

  LAST_CLEANUP = now
end

function match_vpn_flow(p1, p2, server, cert, hasStart)
  if p1 == "OpenVpn" then
    setProfile(PROFILES.vpn)
    return true
  end

  return false
end

function match_video_flow(p1, p2, server)
  for i=1, #VIDEO_HOST_URLS_P do
    if server:find(VIDEO_HOST_URLS_P[i]) then
      setProfile(PROFILES.video)
      return true
    end
  end

  -- TODO HTTP content type

  return false
end

function match_mail_flow(p1, p2, server)
  if p1 == "POP3" then
    setProfile(PROFILES["mail.recv"])
    return true
  end

  if p1 == "SMTP" or p1 == "SMTPS" then
    setProfile(PROFILES["mail.send"])
    return true
  end

  if p1 == "IMAP" or p1 == "IMAPS" then
    -- TODO remove IMAP sync
  end

  return false
end

-------

function flowUpdate()
  --~ clean_web_flows()

  --~ local profile = flow.getProfileId()

  -- debug: to see unmatched flows
  --~ if (profile == PROFILES.other) then
    --~ print("\t"..flow.getNdpiProto().." "..flow.getServerName().."\n")
  --~ end
end

function flowDetect()
  local proto = split_proto(flow.getNdpiProto())
  local p1 = proto["main"]
  local p2 = proto["sub"]
  local srv = flow.getServerName()

  -- exclude DNS by now
  if p1 == "DNS" then
    return
  end

  -- rules
  local matched =
    match_vpn_flow(p1, p2, srv, flow.getSSLCertificate(), flow.hasStart()) or
    match_video_flow(p1, p2, srv) or
    match_mail_flow(p1, p2, srv) or
    match_web_flow(p1, p2, srv, flow.getHTTPUrl())
end

function flowCreate()
  -- print("flowCreate()\n")
end

function flowDelete()
  local proto = split_proto(flow.getNdpiProto())["main"]

  if proto ~= "DNS" and flow.getProfileId() == PROFILES.other then
    printFlow()
  end
end
