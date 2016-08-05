--
-- (C) 2016 - ntop.org
--

print("Initialized script housekeeping.lua\n")

-- Protocols (aggregated as well)
WEB_INDICATORS_PROTOS = {
  "Cloudflare"
}
-- Sites with patterns
--  optional www prefix is always implicit
--  a starting '.' indicates something must appear before the dot
--  a ending '.' indicates 2 to 3 letters should appear after the dot
WEB_INDICATORS = {
  -- Analytics
  "scorecardresearch.com",
  "google-analytics.com",
  "d.turn.com",
  "statse.webtrendslive.com",
  "hm.webtrends.com",
  "google-analytics.com",
  "pixel.quantserve.com",
  "edge.quantserve.com",

  -- Advertising
  ".popads.net",
  "doubleclick.net",
  "googleadservices.com",
  "srv.juiceadv.com",

  -- CDN
  ".stack.imgur.com",
  ".cloudflare.com",
  ".gstatic.com",
  ".clicktale.net",
  ".muscache.com",
  ".deploy.static.akamaitechnologies.com",
  "cdn.sstatic.net",
  "engine.adzerk.net",
  "static.adzerk.net",
  "fonts.googleapis.com",
  "fonts.gstatic.com",
  "ajax.googleapis.com",
  "cdn.siftscience.com",
  "cdn.turn.com",

  -- Search Engine and sites
  ".duckduckgo.com",
  ".bing.com",
  ".search.msn.com",
  ".yahoo.",
  ".forumfree.",
  ".forumcommunity.",
  ".altervista.",
  "stackoverflow.com",
  "github.com"
}

VIDEO_HOST_URLS = {
  ".oloadcdn.net",                        -- Openload
  ".googlevideo.com",                     -- GoogleVideo
  "video-cdg2-1.xx.fbcdn.net"             -- Facebook video
}

HTTP_MAX_AGGR_TIME = 10                   -- assume HTTP_MAX_AGGR_TIME < time to GC a flow
LAST_AGGR_TIME = 0
HTTP_FLOW_BUF = {}

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

function match_url(url, arr)
  local e
  local u
  local m
  local dot = string.byte(".", 1)

  for i=1,#arr do
    e = arr[i]
    u = string.gsub(url, "^www[0-9]?%.", "")

    -- starting characters
    if string.byte(e, 1) == dot then
      u, m = string.gsub(u, "^[a-z0-9-]+%.", ".")
    else
      m = 1
    end

    if m == 1 then
      -- ending characters
      if string.byte(e, #e) == dot then
        u, m = string.gsub(u, "%.[a-z]?[a-z]?[a-z]?$", ".")
      else
        m = 1
      end

      if m == 1 and u == e then
        return i
      end
    end
  end

  return false
end

-------

function match_web_protos(p1)
  for i=1, #WEB_INDICATORS_PROTOS do
    if p1 == WEB_INDICATORS_PROTOS[i] then
      return i
    end
  end
  return false
end

function _match_web_flow(p1, p2, server, url)
  if not is_http_proto(p1) then
    return false
  end

  if p1 == "HTTP" and not url then
    -- site with no url: assume web
    return true
  end

  if match_web_protos(p1) then
    return true
  end

  if url and match_url(url, WEB_INDICATORS) then
    return true
  end

  return false
end

function _debug(url, server, p1)
  -- Debug: mark with a * matched urls
  local m = ""
  if url and match_url(url, WEB_INDICATORS) then
    m = "* "
  else
    if match_web_protos(p1) then
      m = "@ "
    else
      if p1 == "HTTP" and not url then
        m = "# "
      end
    end
  end

  io.write(m)
  --
end

function is_http_proto(p1)
  return p1 == "HTTP" or p1 == "SSL" or p1 == "Cloudflare"
end

function match_web_flow(p1, p2, server, url)
  local matched = false
  local now = flow.getLastSeen()
  local http_proto = is_http_proto(p1)

  clean_web_flows(now)

  if _match_web_flow(p1, p2, server) then
    matched = true
    LAST_AGGR_TIME = now

    -- Aggregate
    for i=1, #HTTP_FLOW_BUF do
      bufferedCallback(i, function () setProfile(PROFILES.web) end)
    end
    HTTP_FLOW_BUF = {}
  else
    if now - LAST_AGGR_TIME <= HTTP_MAX_AGGR_TIME and http_proto then
      matched = true
    end
  end

  if matched then
    _debug(url, server, p1)
    setProfile(PROFILES.web)
    return true
  end

  if http_proto then
    table.insert(HTTP_FLOW_BUF, {["f"]=flow.getRef(), ["t"]=now})
  end

  return false
end

function clean_web_flows(now)
  for i=#HTTP_FLOW_BUF,1,-1  do
    -- Remove out of time or with already detected profiles flows
    if now - HTTP_FLOW_BUF[i].t > HTTP_MAX_AGGR_TIME or
      bufferedCallback(i, function () return flow.getProfileId() end) ~= PROFILES.other then
      table.remove(HTTP_FLOW_BUF, i)
    end
  end
end

function match_vpn_flow(p1, p2, server, cert, hasStart)
  if p1 == "OpenVpn" then
    setProfile(PROFILES.vpn)
    return true
  end

  return false
end

function match_video_flow(p1, p2, server)
  if match_url(server, VIDEO_HOST_URLS) then
    return true
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

-- NB this is called periodically, do not works well on captures
function flowUpdate()
  if flow.getProfileId() == PROFILES.web then
    LAST_AGGR_TIME = math.max(flow.getLastSeen(), LAST_AGGR_TIME)
  end
end

function flowDetect()
  local proto = split_proto(flow.getNdpiProto())
  local p1 = proto["main"]
  local p2 = proto["sub"]
  local srv = flow.getServerName()

  -- exclude DNS
  if p1 == "DNS" then
    return
  end

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

  -- print unmatched protos
  if proto ~= "DNS" and flow.getProfileId() == PROFILES.other then
    io.write("? ")
    printFlow()
  end
end
