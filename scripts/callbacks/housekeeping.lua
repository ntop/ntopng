--
-- (C) 2016 - ntop.org
--

local trace_hk = false

if(trace_hk) then print("Initialized script housekeeping.lua\n") end

-- Protocols which are 100% web indicators
WEB_PROTOS = {
  "Cloudflare"
}
-- Sites which are web indicators
-- Notes:
--  * optional www prefix is always implicit
--  * string end must match
--  * a ending '.' indicates 2 to 3 letters should appear after the dot
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
  ".akamaitechnologies.com",
  "cdn.sstatic.net",
  "engine.adzerk.net",
  "static.adzerk.net",
  "fonts.googleapis.com",
  "ajax.googleapis.com",
  "cdn.siftscience.com",
  "cdn.turn.com",
  ".intercomcdn.com",
  ".intercomassets.com",
  ".intercom.io",
  ".akamaitechnologies.com",
  ".cloudfront.net",
  ".amazonaws.com",
  ".bootstrapcdn.com",
  ".incapdns.net",
  ".verizondigitalmedia.com",
  ".cachefly.net",
  ".zencdn.net",
  ".jsDelivr.net",
  ".mshcdn.com",
  "scontent-mxp1-1.xx.fbcdn.net",
  "scontent.xx.fbcdn.net",

  -- Search Engine and sites
  ".duckduckgo.com",
  ".bing.com",
  ".search.msn.com",
  ".yahoo.",
  ".forumfree.",
  ".forumcommunity.",
  ".altervista.",
  "stackoverflow.com",
  "github.com",
  "facebook.com"
}

VIDEO_HOST_URLS = {
  ".oloadcdn.net",                        -- Openload
  ".googlevideo.com",                     -- GoogleVideo
  "video-cdg2-1.xx.fbcdn.net",            -- Facebook video
  ".swarmcdn.com",
}

HTTP_MAX_AGGR_TIME = 10                   -- assume HTTP_MAX_AGGR_TIME < time to GC a flow
LAST_AGGR_TIME = 0
HTTP_FLOW_BUF = {}

-------

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
  if trace_hk then printFlow() end
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

    if string.byte(e, #e) == dot then
      u, m = string.gsub(u, "%.[a-z]?[a-z]?[a-z]?$", ".")
    else
      m = 1
    end

    if m == 1 then
      m = string.find(u, e, 1, true)
      if m and m + string.len(e) - 1 == string.len(u) then
        return i
      end
    end
    --~ end
  end

  return false
end

-------

function match_web_protos(p1)
  for i=1, #WEB_PROTOS do
    if p1 == WEB_PROTOS[i] then
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

  if match_url(server, WEB_INDICATORS) then
    return true
  end

  return false
end

function _debug(url, server, p1)
  -- Debug: mark with a * matched urls
  local m = ""
  if match_url(server, WEB_INDICATORS) then
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
    if trace_hk then
      _debug(url, server, p1)
    end
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
    -- Remove out of time flows or with already detected profiles
    if now - HTTP_FLOW_BUF[i].t > HTTP_MAX_AGGR_TIME or
      bufferedCallback(i, function () return flow.getProfileId() end) ~= PROFILES.other then
      table.remove(HTTP_FLOW_BUF, i)
    end
  end
end

function match_vpn_flow(p1, p2, server)
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

-- NB this is called periodically, so it doesn't apply to capture files
function flowUpdate(f)
  --~ if(trace_hk) then print("flowUpdate()\n") end

  if flow.getProfileId() == PROFILES.web then
    LAST_AGGR_TIME = math.max(flow.getLastSeen(), LAST_AGGR_TIME)
  end
end

function flowDetect(f)
  local proto = split_proto(flow.getNdpiProto())
  local p1 = proto["main"]
  local p2 = proto["sub"]
  local srv = flow.getServerName()

  -- exclude DNS
  if p1 == "DNS" then
    return
  end

  local matched =
    match_vpn_flow(p1, p2, srv) or
    match_video_flow(p1, p2, srv) or
    match_mail_flow(p1, p2, srv) or
    match_web_flow(p1, p2, srv, flow.getHTTPUrl())
end

function flowCreate(f)
   --~ if(trace_hk) then print("flowCreate()\n") end
end

function flowDelete(f)
  local proto = split_proto(flow.getNdpiProto())["main"]

  --~ if(trace_hk) then print("flowDelete()\n") end

  -- print unmatched protos
  if proto ~= "DNS" and flow.getProfileId() == PROFILES.other then
    if trace_hk then
      io.write("? ")
      printFlow()
    end
  end
end
