--
-- (C) 2014-16 - ntop.org
--
require "lua_trace"


-- ##########################################

function aggregateInterfaceStats(ifstats)
   if(ifstats == nil) then return(ifstats) end

   local tot = {}

   for ifname,_v in pairs(ifstats["interfaces"]) do
      for k,v in pairs(ifstats["interfaces"][ifname]) do
	 if(type(v) ~= "table") then
	    if((tot[k] == nil) and (k ~= "id") and (k ~= "name")) then
	       --io.write(k.."\n")
	       tot[k] = v
	    end
	 end
      end

      keys = { "stats" }
      for _,key in pairs(keys) do
	 for k,v in pairs(_v[key]) do
	    --io.write(k.."\n")
	    if(tot[k] == nil) then tot[k] = 0 end
	    tot[k] = tot[k] + v
	 end
      end

      keys = { "profiles" }
      for _,key in pairs(keys) do
	 if(_v[key] ~= nil) then
	   tot[key] = {}
	   for k,v in pairs(_v[key]) do
	      --io.write(k.."\n")
	      if(tot[key][k] == nil) then tot[key][k] = 0 end
	      tot[key][k] = tot[key][k] + v
	   end
	 end
      end

      keys = { "pktSizeDistribution" }
      for _,key in pairs(keys) do
	 if(tot[key] == nil) then tot[key] = { } end

	 for k,v in pairs(_v[key]) do
	    --io.write(k.."\n")
	    if(tot[key][k] == nil) then tot[key][k] = 0 end
	    tot[key][k] = tot[key][k] + v
	 end
      end

      keys = { "tcpFlowStats" }
      for _,key in pairs(keys) do
	 if(tot[key] == nil) then tot[key] = { } end

	 if(_v[key] ~= nil) then 
  	   for k,v in pairs(_v[key]) do
	    --io.write(k.."\n")
	    if(tot[key][k] == nil) then tot[key][k] = 0 end
	    tot[key][k] = tot[key][k] + v
         end
  	 end
      end

      keys = { "tcpPacketStats" }
      for _,key in pairs(keys) do
	 if(tot[key] == nil) then tot[key] = { } end

	 if(_v[key] ~= nil) then 
  	   for k,v in pairs(_v[key]) do
	    --io.write(k.."\n")
	    if(tot[key][k] == nil) then tot[key][k] = 0 end
	    tot[key][k] = tot[key][k] + v
	   end
	 end
      end

      keys = { "localstats", "ndpi" }
      for _,key in pairs(keys) do
	 if(tot[key] == nil) then tot[key] = { } end
	 -- io.write(key.."\n")

	 for k,v in pairs(_v[key]) do
	    if(tot[key][k] == nil) then tot[key][k] = { } end
	    for k1,v1 in pairs(_v[key][k]) do
	       -- io.write(k1.."="..type(v1).."\n")

	       if(type(v1) == "number") then
		  if(tot[key][k][k1] == nil) then
		     tot[key][k][k1] = 0
		  end
		  tot[key][k][k1] = tot[key][k][k1] + v1
		  -- io.write("tot["..key.."]["..k.."]["..k1.."]="..tot[key][k][k1].."\n")
	       else
		  tot[key][k][k1] = v1
	       end
	    end
	 end
      end
   end

   for k,v in pairs(tot) do
      ifstats[k] = v
   end

   return(ifstats)
end

-- ##########################################

function aggregateGroupStats(groupStats)
   if(groupStats == nil) then return(groupStats) end

   local tot = 0
   local res = { }
   for ifname,_v in pairs(groupStats) do
      for k,v in pairs(_v["groups"]) do
	 if k == nil or v == nil or type(v) ~= 'table' then
	    goto continue
	 end
	 if res[k] == nil then
	    res[k] = {}
	 end
	 for prop_name, prop_value in pairs(v) do
	    if res[k][prop_name] == nil then
	       res[k][prop_name] = prop_value
	    elseif type(prop_value) == 'number' then
	       res[k][prop_name] = res[k][prop_name] + prop_value
	    end
	 end
	 ::continue::
      end
      tot = tot + _v["numGroupedHosts"]
   end

   return res,tot
end

-- ##########################################

function aggregateHostsStats(hostStats)
   if(hostStats == nil) then return(hostStats) end

   local tot = 0
   local res = { }
   for ifname,_v in pairs(hostStats) do
      for k,v in pairs(_v["hosts"]) do
	    --io.write(k.."\n")
	    res[k] = v
      end

      tot = tot + _v["numHosts"]
   end

   return res,tot
end

-- ##########################################

function aggregateFlowsStats(flowstats)
   -- TODO: prevent possible flow overlap when using interface views
   if(flowstats == nil) then return(flowstats) end

   local tot = 0
   local res = { }
   for ifname,_v in pairs(flowstats) do
      for k,v in ipairs(_v["flows"]) do
	    --io.write(k.."\n")
	    res[k] = v
      end

      tot = tot + _v["numFlows"]
   end

   return res,tot
end

-- ##############################################

function getInterfaceName(interface_id)
   local ifnames = interface.getIfNames()

   interface_id = tonumber(interface_id)
   for _,if_name in pairs(ifnames) do
      --io.write(if_name.."\n")
      interface.select(if_name)
      _ifstats = interface.getStats()
      _ifstats = aggregateInterfaceStats(_ifstats)
      if(_ifstats.id == interface_id) then
	 return(_ifstats.name)
      end
   end

   return("")
end

-- ##############################################

function getInterfaceId(interface_name)
   return(interface.name2id(interface_name))
end

-- Note that ifname can be set by Lua.cpp so don't touch it if already defined
if((ifname == nil) and (_GET ~= nil)) then
  ifname = _GET["ifname"]

  if(ifname ~= nil) then
     if(ifname.."" == tostring(tonumber(ifname)).."") then
	-- ifname does not contain the interface name but rather the interface id
	ifname = getInterfaceName(ifname)
	if(ifname == "") then ifname = nil end
     end
  end

  if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => Session:".._SESSION["session"]) end

  if((ifname == nil) and (_SESSION ~= nil)) then
    if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => set ifname by _SESSION value") end
    ifname = _SESSION["ifname"]
    if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => ifname:"..ifname) end
  else
    if(debug_session) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Session => set ifname by _GET value") end
  end
end

--print("(((("..ifname.."))))")
l4_keys = {
  { "TCP", "tcp", 6 },
  { "UDP", "udp", 17 },
  { "ICMP", "icmp", 1 },
  { "Other IP", "other ip", -1 }
}

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

-- ##############################################

function sendHTTPHeaderIfName(mime, ifname, maxage, content_disposition)
  info = ntop.getInfo(false)

  print('HTTP/1.1 200 OK\r\n')
  print('Cache-Control: max-age=0, no-cache, no-store\r\n')
  print('Server: ntopng '..info["version"]..' ['.. info["platform"]..']\r\n')
  print('Pragma: no-cache\r\n')
  print('X-Frame-Options: DENY\r\n')
  print('X-Content-Type-Options: nosniff\r\n')
  if(_SESSION ~= nil) then print('Set-Cookie: session='.._SESSION["session"]..'; max-age=' .. maxage .. '; path=/; HttpOnly\r\n') end
  if(ifname ~= nil) then print('Set-Cookie: ifname=' .. ifname .. '; path=/\r\n') end
  print('Content-Type: '.. mime ..'\r\n')
  if(content_disposition ~= nil) then print('Content-Disposition: '..content_disposition..'\r\n') end
  print('Last-Modified: '..os.date("!%a, %m %B %Y %X %Z").."\r\n")
  print('\r\n')
end

-- ##############################################

function sendHTTPHeaderLogout(mime, content_disposition)
  sendHTTPHeaderIfName(mime, nil, 0, content_disposition)
end

-- ##############################################

function sendHTTPHeader(mime, content_disposition)
  sendHTTPHeaderIfName(mime, nil, 3600, content_disposition)
end

-- ##############################################

function printGETParameters(get)
  for key, value in pairs(get) do
    io.write(key.."="..value.."\n")
  end
end

-- ##############################################

function isEmptyString(str)
  -- io.write(str..'\n')
  if((str == nil) or (str == "")) then
    return true
  else
    return false
  end
end

-- ##############################################

-- Simplified checker
function isIPv6String(ip)
  if(string.find(ip, ":") ~= nil) then
     return true
  end

    return false
end

-- ##############################################

function findString(str, tofind)
  if(str == nil) then return(nil) end
  if(tofind == nil) then return(nil) end

  str1    = string.lower(string.gsub(str, "-", "_"))
  tofind1 = string.lower(string.gsub(tofind, "-", "_"))

  return(string.find(str1, tofind1, 1))
end

-- ##############################################

function findStringArray(str, tofind)
  if(str == nil) then return(nil) end
  if(tofind == nil) then return(nil) end
  local rsp = false

  for k,v in pairs(tofind) do
    str1    = string.gsub(str, "-", "_")
    tofind1 = string.gsub(v, "-", "_")
    if(str1 == tofind1) then
      rsp = true
    end

  end

  return(rsp)
end

-- ##############################################

function string.contains(String,Start)
   if type(String) ~= 'string' or type(Start) ~= 'string' then
      return false
   end
   return(string.find(String,Start,1) ~= nil)
end

-- ##############################################

function string.starts(String,Start)
   if type(String) ~= 'string' or type(Start) ~= 'string' then
      return false
   end
   return string.sub(String,1,string.len(Start))==Start
end

-- ##############################################

function string.ends(String,End)
   if type(String) ~= 'string' or type(End) ~= 'string' then
      return false
   end
   return End=='' or string.sub(String,-string.len(End))==End
end

-- ##############################################

function printASN(asn, asname)
  asname = asname:gsub('"','')
  if(asn > 0) then
    return("<A HREF='http://as.robtex.com/as"..asn..".html' title='"..asname.."'>"..asname.."</A> <i class='fa fa-external-link fa-lg'></i>")
  else
    return(asname)
  end
end

-- ##############################################

function shortenString(name)
   max_len = 24
    if(string.len(name) < max_len) then
      return(name)
   else
      return(string.sub(name, 1, max_len).."...")
   end
end

-- ##############################################

function shortHostName(name)
  local chunks = {name:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
  if(#chunks == 4) then
    return(name)
  else
    max_len = 24

    chunks = {name:match("%w+:%w+:%w+:%w+:%w+:%w+")}
    --io.write(#chunks.."\n")
    if(#chunks == 1) then
      return(name)
    end

    if(string.len(name) < max_len) then
      return(name)
    else
      tot = 0
      n = 0
      ret = ""

      for token in string.gmatch(name, "([%w-]+).") do
	if(tot < max_len) then
	  if(n > 0) then ret = ret .. "." end
	  ret = ret .. token
	  tot = tot+string.len(token)
	  n = n + 1
	end
      end

      return(ret .. "...")
    end
  end

  return(name)
end

-- ##############################################

function _handleArray(name, sev)
  local id

  for id, _ in ipairs(name) do
    local l = name[id][1]
    local key = name[id][2]

    if(string.upper(key) == string.upper(sev)) then
      return(l)
    end
  end

  return(firstToUpper(sev))
end

-- ##############################################

function l4Label(proto)
  return(_handleArray(l4_keys, proto))
end

-- Alerts (see ntop_typedefs.h)

alert_level_keys = {
  { "<span class='label label-info'>Info</span>", 0 },
  { "<span class='label label-warning'>Warning</span>", 1 },
  { "<span class='label label-danger'>Error</span>", 2 }
}

alert_type_keys = {
  { "<i class='fa fa-tint'></i> TCP SYN Flood", 0 },
  { "<i class='fa fa-tint'></i> Flows Flood",   1 },
  { "<i class='fa fa-arrow-circle-up'></i> Threshold Cross",  2 },
  { "<i class='fa fa-frown-o'></i> Blacklist Host",  3 },
  { "<i class='fa fa-clock-o'></i> Periodic Activity",  4 },
  { "<i class='fa fa-sort-asc'></i> Quota Exceeded",  5 },
  { "<i class='fa fa-ban'></i> Malware Detected",  6 },
  { "<i class='fa fa-bomb'></i> Ongoing Attacker",  7 },
  { "<i class='fa fa-bomb'></i> Under Attack",  8 },
  { "<i class='fa fa-exclamation'></i> Misconfigured App",  9 },
  { "<i class='fa fa-exclamation'></i> Suspicious Activity",  10 },
}

function alertSeverityLabel(v)
  return(_handleArray(alert_level_keys, tonumber(v)))
end

function alertTypeLabel(v)
  return(_handleArray(alert_type_keys, tonumber(v)))
end

function firstToUpper(str)
  str = tostring(str)
  return (str:gsub("^%l", string.upper))
end

function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function pairsByValues(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, function(x, y) return f(t[x], t[y]) end)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function asc(a,b)
  return (a < b)
end

function rev(a,b)
  return (a > b)
end

--for _key, _value in pairsByKeys(vals, rev) do
--   print(_key .. "=" .. _value .. "\n")
--end

function round(num, idp) return tonumber(string.format("%." .. (idp or 0) .. "f", num)) end
--function round(num) return math.floor(num+.5) end

-- Note that the function below returns a string as returnong a number
-- would not help as a new float would be returned
function toint(num)
   return string.format("%u", num)
end

-- Convert bytes to human readable format
function bytesToSize(bytes)
   if(bytes == nil) then
      return("0")
   else
      precision = 2
      kilobyte = 1024;
      megabyte = kilobyte * 1024;
      gigabyte = megabyte * 1024;
      terabyte = gigabyte * 1024;

      bytes = tonumber(bytes)
      if((bytes >= 0) and (bytes < kilobyte)) then
	 return round(bytes, precision) .. " B";
	 elseif((bytes >= kilobyte) and (bytes < megabyte)) then
	 return round(bytes / kilobyte, precision) .. ' KB';
	 elseif((bytes >= megabyte) and (bytes < gigabyte)) then
	 return round(bytes / megabyte, precision) .. ' MB';
	 elseif((bytes >= gigabyte) and (bytes < terabyte)) then
	 return round(bytes / gigabyte, precision) .. ' GB';
	 elseif(bytes >= terabyte) then
	 return round(bytes / terabyte, precision) .. ' TB';
      else
	 return round(bytes, precision) .. ' B';
      end
   end
end

-- Convert bits to human readable format

function bitsToSizeMultiplier(bits, multiplier)
  precision = 2
  kilobit = 1000;
  megabit = kilobit * multiplier;
  gigabit = megabit * multiplier;
  terabit = gigabit * multiplier;

  if((bits >= kilobit) and (bits < megabit)) then
    return round(bits / kilobit, precision) .. ' Kbit';
  elseif((bits >= megabit) and (bits < gigabit)) then
    return round(bits / megabit, precision) .. ' Mbit';
  elseif((bits >= gigabit) and (bits < terabit)) then
    return round(bits / gigabit, precision) .. ' Gbit';
  elseif(bits >= terabit) then
    return round(bits / terabit, precision) .. ' Tbit';
  else
    return round(bits, precision) .. ' bps';
  end
end

function bitsToSize(bits)
  return(bitsToSizeMultiplier(bits, 1000))
end

-- Convert packets to pps readable format
function pktsToSize(pkts)
  precision = 2
  if     (pkts >= 1000000) then return round(pkts/1000000, precision)..' Mpps';
  elseif(pkts >=    1000) then return round(pkts/   1000, precision)..' Kpps';
  else                     return round(pkts        , precision)..' pps';
  end
end

function formatValue(amount)
  local formatted = amount

  if(formatted == nil) then return(0) end
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if(k==0) then
      break
    end
  end
  return formatted
end

function formatPackets(amount)
   return formatValue(tonumber(amount)).." Pkts"
end

function capitalize(str)
  return (str:gsub("^%l", string.upper))
end


function isnumber(str)
   if((str ~= nil) and (string.len(str) > 0) and (tonumber(str) ~= nil)) then
      return(true)
   else
      return(false)
   end
end

function split(pString, pPattern)
  local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
  local fpat = "(.-)" .. pPattern
  local last_end = 1
  local s, e, cap = pString:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(Table,cap)
    end
    last_end = e+1
    s, e, cap = pString:find(fpat, last_end)
  end
  if last_end <= #pString then
    cap = pString:sub(last_end)
    table.insert(Table, cap)
  end
  return Table
end

-- returns the MAXIMUM value found in a table t, together with the corresponding
-- index argmax. a pair argmax, max is returned.
function tmax(t)
    local argmx, mx = nil, nil
    if (type(t) ~= "table") then return nil, nil end
    for k, v in pairs(t) do
	-- first iteration
	if mx == nil and argmx == nil then
	    mx = v
	    argmx = k
	elseif (v == mx and k > argmx) or v > mx then
	-- if there is a tie, prefer the greatest argument
	-- otherwise grab the maximum
	    argmx = k
	    mx = v
	end
    end
    return argmx, mx
end

-- returns the MINIMUM value found in a table t, together with the corresponding
-- index argmin. a pair argmin, min is returned.
function tmin(t)
    local argmn, mn = nil, nil
    if (type(t) ~= "table") then return nil, nil end
    for k, v in pairs(t) do
	-- first iteration
	if mn == nil and argmn == nil then
	    mn = v
	    argmn = k
	elseif (v == mn and k > argmn) or v < mn then
	-- if there is a tie, prefer the greatest argument
	-- otherwise grab the minimum
	    argmn = k
	    mn = v
	end
    end
    return argmn, mn
end

string.split = function(s, p)
  local temp = {}
  local index = 0
  local last_index = string.len(s)

  while true do
    local i, e = string.find(s, p, index)

    if i and e then
      local next_index = e + 1
      local word_bound = i - 1
      table.insert(temp, string.sub(s, index, word_bound))
      index = next_index
    else
      if index > 0 and index <= last_index then
	table.insert(temp, string.sub(s, index, last_index))
      elseif index == 0 then
	temp = nil
      end
      break
    end
  end

  return temp
end

function formatEpoch(epoch)
  return(os.date("%d/%m/%Y %X", epoch))
end

function secondsToTime(seconds)
  if(seconds == nil) then return "" end
  if(seconds < 1) then
    return("< 1 sec")
  end

  days = math.floor(seconds / 86400)
  hours =  math.floor((seconds / 3600) - (days * 24))
  minutes = math.floor((seconds / 60) - (days * 1440) - (hours * 60))
  sec = seconds % 60
  msg = ""

  if(days > 0) then
    years = math.floor(days/365)

    if(years > 0) then
      days = days % 365

      msg = years .. " year"
      if(years > 1) then msg = msg .. "s" end
   end

    if(days > 0) then
       if(string.len(msg) > 0) then  msg = msg .. ", " end
      msg = msg .. days .. " day"
      if(days > 1) then msg = msg .. "s" end
    end
  end

  if(hours > 0) then
     if(string.len(msg) > 0) then  msg = msg .. ", " end
    msg = msg .. string.format("%d ", hours)
    if(hours > 1) then
      msg = msg .. "h"
    else
      msg = msg .. "h"
    end

    --if(hours > 1) then msg = msg .. "s" end
  end

  if(minutes > 0) then
     if(string.len(msg) > 0) then msg = msg .. ", " end
     msg = msg .. string.format("%d min", minutes)
  end

  if(sec > 0) then
    if((string.len(msg) > 0) and (minutes > 0)) then msg = msg .. ", " end
    msg = msg .. string.format("%d sec", sec);
  end

  return msg
end

function msToTime(ms)
  if(ms > 1000) then
    return secondsToTime(ms/1000)
  else
    if(ms < 1) then
      return("< 1 ms")
    else
      return(round(ms, 4).." ms")
    end
  end
end

function starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

-- #################################################################

-- NOTE keep in sync with Flashstart::initMapping()

host_categories =	 {
      ["freetime"] = "FreeTime",
      ["chat"] = "Chat",
      ["onlineauctions"] = "Auctions",
      ["onlinegames"] = "Online Games",
      ["pets"] = "Animals",
      ["porn"] = "Porn",
      ["religion"] = "Religion",
      ["phishing"] = "Phishing",
      ["sexuality"] = "Sex",
      ["games"] = "Games",
      ["socialnetworking"] = "SocialNetwork",
      ["jobsearch"] = "JobSearch",
      ["mail"] = "Webmail",
      ["news"] = "News",
      ["proxy"] = "AnonymousProxy",
      ["publicite"] = "Advertisement",
      ["sports"] = "Sport",
      ["vacation"] = "Travel",
      ["ecommerce"] = "E-commerce",
      ["instantmessaging"] = "InstantMessaging",
      ["kidstimewasting"] = "KidGames",
      ["audio-video"] = "AudioVideo",
      ["books"] = "Books",
      ["government"] = "Gouvernment",
      ["malware"] = "Malware",
      ["medical"] = "Medicine",
      ["ann"] = "Ads",
      ["drugs"] = "Drugs",
      ["dating"] = "OnlineDating",
      ["desktopsillies"] = "DesktopImages",
      ["filehosting"] = "FileHosting",
      ["filesharing"] = "FileSharing",
      ["gambling"] = "Gambling",
      ["warez"] = "CracksWarez",
      ["radio"] = "Radio",
      ["updatesites"] = "Updates",
      ["financial"] = "FinanceBanking",
      ["adult"] = "Adults",
      ["fashion"] = "Fashion",
      ["showbiz"] = "Showbiz",
      ["ict"] = "ICT",
      ["company"] = "Business",
      ["education"] = "EducationSchool",
      ["searchengines"] = "SearchEngines",
      ["blog"] = "Blog",
      ["association"] = "Associations",
      ["music"] = "Musica",
      ["legal"] = "Legal",
      ["photo"] = "Photo",
      ["stats"] = "Webstat",
      ["content"] = "ContentServer",
      ["domainforsale"] = "DomainForSale",
      ["weapons"] = "Guns",
      ["generic"] = "Generic"
}

-- #################################################################

function getCategoryLabel(cat)
   if((cat == "") or (cat == nil) or (cat == "???")) then
      return("")
   end

  for c,v in pairs(host_categories) do
   if(c == cat) then
     return(v)
   end
  end

  return(cat)
end

function getCategoryIcon(what, cat)
   if((cat == "") or (cat == nil) or (cat == "???")) then
      return("")
   end

  ret = ""
  for c,_ in pairs(cat) do
   if(host_categories[c] ~= nil) then
     ret = ret .. " <span class='label label-info'>"..host_categories[c].."</span>"
   else
     ret = ret .. " <span class='label label-info'>"..c.."</span>"
   end
  end

  return(ret)
end


function abbreviateString(str, len)
  if(str == nil) then
    return("")
  else
    if(string.len(str) < len) then
      return(str)
    else
      return(string.sub(str, 1, len).."...")
    end
  end
end

function bit(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

-- Typical call:  if hasbit(x, bit(3)) then ...
function hasbit(x, p)
  return x % (p + p) >= p
end

function setbit(x, p)
  return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
  return hasbit(x, p) and x - p or x
end

function isBroadMulticast(ip)
   if(ip == "0.0.0.0") then
      return true
   end
   -- print(ip)
   t = string.split(ip, "%.")
   -- print(table.concat(t, "\n"))
   if(t == nil) then
      return false  -- Might be an IPv6 address
   else
      if(tonumber(t[1]) >= 224)  then
	 return true
      end
   end

   return false
end

function isBroadcastMulticast(ip)
   -- check NoIP
   if(ip == "0.0.0.0") then
      return true
   end

   -- check IPv6
   t = string.split(ip, "%.")

   if(t ~= nil) then
      -- check Multicast / Broadcast
      if(tonumber(t[1]) >= 224) then
	 return true
      end
   end

   return false
end

function isIPv4(ip)
  if string.find(ip, "%.") then
    return true
  end
  return false
end


function isIPv6(ip)
   if string.find(ip, "%.") then
     return false
  end
  return true
end

function addGoogleMapsScript()
   local g_maps_key = ntop.getCache('ntopng.prefs.google_apis_browser_key')
   if g_maps_key ~= nil and g_maps_key~= "" then
      g_maps_key = "&key="..g_maps_key
   else
   g_maps_key = ""
   end
   print("<script src=\"https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false"..g_maps_key.."\"></script>\n")
end

function addLogoSvg()
   print [[
<svg width="103px" height="50px" viewBox="0 0 103 50" version="1.1" xmlns="http://www.w3.org/2000/svg">
<path fill="#fbfbfb" d=" M 0.00 0.00 L 103.00 0.00 L 103.00 50.00 L 0.00 50.00 L 0.00 0.00 Z" />
<path fill="#e0dfdf" d=" M 4.85 1.48 C 6.22 1.31 7.60 1.22 8.98 1.21 C 37.00 1.18 65.02 1.25 93.03 1.19 C 95.53 1.45 98.91 1.02 100.31 3.63 C 101.57 5.50 101.41 7.84 101.46 9.98 C 101.41 20.66 101.49 31.34 101.42 42.02 C 101.47 44.44 100.55 47.12 98.30 48.31 C 95.68 49.45 92.76 48.78 90.01 48.81 C 65.02 48.80 40.02 48.83 15.02 48.80 C 11.70 48.82 8.35 49.28 5.04 48.72 L 5.39 47.64 C 8.24 47.83 11.09 48.07 13.95 48.13 C 39.31 48.15 64.66 48.12 90.02 48.15 C 92.91 48.15 95.79 47.82 98.63 47.31 C 98.05 46.60 97.37 45.99 96.61 45.49 L 95.99 45.06 C 96.80 44.80 98.40 44.30 99.21 44.04 L 99.36 44.03 C 99.50 44.03 99.79 44.02 99.93 44.01 C 100.48 31.44 100.36 18.75 100.14 6.16 C 99.85 5.82 99.28 5.16 99.00 4.83 L 98.05 4.18 C 97.44 3.75 96.83 3.33 96.22 2.91 C 95.08 1.78 93.46 1.86 91.98 1.84 C 65.31 2.00 38.64 1.81 11.97 1.92 C 9.59 1.93 7.19 1.95 4.85 1.48 Z" />
<path fill="#fdc28e" d=" M 2.40 4.64 C 3.22 4.02 4.05 3.42 4.88 2.81 C 35.32 2.80 65.78 2.61 96.22 2.91 C 96.83 3.33 97.44 3.75 98.05 4.18 C 97.94 10.99 97.98 17.80 98.03 24.61 C 94.33 24.55 90.63 24.55 86.93 24.61 C 87.03 20.61 85.58 16.14 81.83 14.17 C 79.15 12.57 75.83 13.14 73.29 14.71 C 72.19 14.27 71.09 13.86 69.98 13.48 C 68.39 13.87 67.26 15.25 67.53 16.92 C 67.45 19.53 67.54 22.13 67.52 24.74 C 67.13 24.69 66.35 24.59 65.97 24.55 C 65.86 21.70 65.76 18.50 63.66 16.31 C 60.13 12.15 52.85 12.14 49.37 16.37 C 47.35 18.58 46.81 21.64 46.81 24.53 C 45.41 24.56 44.01 24.59 42.61 24.62 C 42.59 22.97 42.57 21.32 42.60 19.68 C 43.90 19.29 45.26 19.07 46.53 18.57 C 47.29 17.40 47.41 15.65 46.54 14.51 C 45.32 14.03 44.05 13.72 42.73 13.58 C 42.78 10.95 42.74 6.67 38.89 7.30 C 36.49 8.54 37.22 11.38 36.92 13.57 C 34.23 13.50 32.07 16.35 34.12 18.59 C 34.83 18.84 36.25 19.33 36.97 19.58 C 37.12 21.25 37.06 22.92 37.06 24.59 C 35.75 24.59 34.44 24.59 33.14 24.61 C 32.96 21.36 33.89 17.35 31.15 14.90 C 28.35 12.51 24.15 12.89 21.14 14.66 C 19.28 13.73 16.40 12.75 15.43 15.37 C 15.10 18.44 15.36 21.53 15.28 24.61 C 11.08 24.54 6.88 24.58 2.69 24.58 C 2.10 17.97 2.69 11.28 2.40 4.64 Z" />
<path fill="#fde2cb" d=" M 98.05 4.18 L 99.00 4.83 C 99.13 17.89 98.72 31.00 99.36 44.03 L 99.21 44.04 L 97.99 43.66 C 98.18 37.32 98.14 30.96 98.03 24.61 C 97.98 17.80 97.94 10.99 98.05 4.18 Z" />
<path fill="#919191" d=" M 99.00 4.83 C 99.28 5.16 99.85 5.82 100.14 6.16 C 100.36 18.75 100.48 31.44 99.93 44.01 C 99.79 44.02 99.50 44.03 99.36 44.03 C 98.72 31.00 99.13 17.89 99.00 4.83 Z" />
<path fill="#ffffff" d=" M 36.92 13.57 C 37.22 11.38 36.49 8.54 38.89 7.30 C 42.74 6.67 42.78 10.95 42.73 13.58 C 44.05 13.72 45.32 14.03 46.54 14.51 C 47.41 15.65 47.29 17.40 46.53 18.57 C 45.26 19.07 43.90 19.29 42.60 19.68 C 42.57 21.32 42.59 22.97 42.61 24.62 C 42.16 27.60 44.14 33.15 39.86 33.86 C 35.40 33.43 37.57 27.54 37.06 24.59 C 37.06 22.92 37.12 21.25 36.97 19.58 C 36.25 19.33 34.83 18.84 34.12 18.59 C 32.07 16.35 34.23 13.50 36.92 13.57 Z" />
<path fill="#ffffff" d=" M 21.14 14.66 C 24.15 12.89 28.35 12.51 31.15 14.90 C 33.89 17.35 32.96 21.36 33.14 24.61 C 33.05 27.07 33.29 29.54 32.95 31.99 C 32.16 34.62 27.92 34.40 27.34 31.72 C 27.19 29.35 27.31 26.98 27.29 24.61 C 27.51 22.14 27.48 18.11 24.05 18.23 C 20.81 18.41 20.90 22.23 21.02 24.62 C 20.99 27.08 21.12 29.55 20.95 32.01 C 20.07 34.59 15.97 34.42 15.33 31.76 C 15.20 29.38 15.32 26.99 15.28 24.61 C 15.36 21.53 15.10 18.44 15.43 15.37 C 16.40 12.75 19.28 13.73 21.14 14.66 Z" />
<path fill="#ffffff" d=" M 49.37 16.37 C 52.85 12.14 60.13 12.15 63.66 16.31 C 65.76 18.50 65.86 21.70 65.97 24.55 C 66.06 29.16 62.74 33.71 57.98 34.13 C 52.20 35.30 46.89 30.21 46.81 24.53 C 46.81 21.64 47.35 18.58 49.37 16.37 Z" />
<path fill="#ffffff" d=" M 73.29 14.71 C 75.83 13.14 79.15 12.57 81.83 14.17 C 85.58 16.14 87.03 20.61 86.93 24.61 C 86.64 28.43 84.48 32.37 80.78 33.78 C 78.26 34.69 75.60 34.08 73.23 33.05 C 73.25 35.33 73.62 37.68 73.06 39.92 C 72.06 42.49 67.59 41.88 67.55 39.02 C 67.45 34.26 67.54 29.50 67.52 24.74 C 67.54 22.13 67.45 19.53 67.53 16.92 C 67.26 15.25 68.39 13.87 69.98 13.48 C 71.09 13.86 72.19 14.27 73.29 14.71 Z" />
<path fill="#fdc28e" d=" M 21.02 24.62 C 20.90 22.23 20.81 18.41 24.05 18.23 C 27.48 18.11 27.51 22.14 27.29 24.61 C 25.20 24.57 23.11 24.57 21.02 24.62 Z" />
<path fill="#fdc28e" d=" M 52.65 24.61 C 52.24 21.99 53.91 18.42 57.03 18.94 C 59.66 19.25 60.63 22.31 60.35 24.61 C 57.79 24.56 55.22 24.56 52.65 24.61 Z" />
<path fill="#fdc28e" d=" M 72.96 25.45 C 73.30 22.95 73.64 19.11 76.92 18.92 C 80.68 18.62 81.33 23.07 81.11 25.88 L 80.87 25.48 L 80.33 24.57 C 78.09 24.72 75.61 24.01 73.55 25.17 L 72.96 25.45 Z" />
<path fill="#fc8a21" d=" M 2.69 24.58 C 6.88 24.58 11.08 24.54 15.28 24.61 C 15.32 26.99 15.20 29.38 15.33 31.76 C 15.97 34.42 20.07 34.59 20.95 32.01 C 21.12 29.55 20.99 27.08 21.02 24.62 C 23.11 24.57 25.20 24.57 27.29 24.61 C 27.31 26.98 27.19 29.35 27.34 31.72 C 27.92 34.40 32.16 34.62 32.95 31.99 C 33.29 29.54 33.05 27.07 33.14 24.61 C 34.44 24.59 35.75 24.59 37.06 24.59 C 37.57 27.54 35.40 33.43 39.86 33.86 C 44.14 33.15 42.16 27.60 42.61 24.62 C 44.01 24.59 45.41 24.56 46.81 24.53 C 46.89 30.21 52.20 35.30 57.98 34.13 C 62.74 33.71 66.06 29.16 65.97 24.55 C 66.35 24.59 67.13 24.69 67.52 24.74 C 67.54 29.50 67.45 34.26 67.55 39.02 C 67.59 41.88 72.06 42.49 73.06 39.92 C 73.62 37.68 73.25 35.33 73.23 33.05 C 75.60 34.08 78.26 34.69 80.78 33.78 C 84.48 32.37 86.64 28.43 86.93 24.61 C 90.63 24.55 94.33 24.55 98.03 24.61 C 98.14 30.96 98.18 37.32 97.99 43.66 L 99.21 44.04 C 98.40 44.30 96.80 44.80 95.99 45.06 C 65.83 44.97 35.66 44.94 5.50 45.07 L 4.31 45.05 C 3.90 44.64 3.08 43.80 2.67 43.38 C 2.79 37.12 2.76 30.84 2.69 24.58 Z" />
<path fill="#fc8a21" d=" M 52.65 24.61 C 55.22 24.56 57.79 24.56 60.35 24.61 C 60.25 27.09 57.56 29.61 55.11 28.23 C 53.54 27.78 53.08 25.97 52.65 24.61 Z" />
<path fill="#fc8a21" d=" M 73.55 25.17 C 75.61 24.01 78.09 24.72 80.33 24.57 L 80.87 25.48 C 80.22 29.65 73.76 29.42 73.55 25.17 Z" />
<path fill="#fdb26d" d=" M 5.50 45.07 C 35.66 44.94 65.83 44.97 95.99 45.06 L 96.61 45.49 C 94.20 46.38 91.57 45.86 89.06 46.00 C 60.87 45.86 32.65 46.28 4.48 45.79 L 5.50 45.07 Z" />
<path fill="#a2a2a2" d=" M 2.04 44.37 L 4.48 45.79 C 32.65 46.28 60.87 45.86 89.06 46.00 C 91.57 45.86 94.20 46.38 96.61 45.49 C 97.37 45.99 98.05 46.60 98.63 47.31 C 95.79 47.82 92.91 48.15 90.02 48.15 C 64.66 48.12 39.31 48.15 13.95 48.13 C 11.09 48.07 8.24 47.83 5.39 47.64 C 4.55 46.82 2.87 45.19 2.04 44.37 Z" />
</svg>
]]
end

function addGauge(name, url, maxValue, width, height)
  if(url ~= nil) then print('<A HREF="'..url..'">') end
  print('<canvas id="'..name..'" height="'..height..'" width="'..width..'"></canvas>\n')
  --   print('<div id="'..name..'-text" style="font-size: 12px;"></div>\n')
  if(url ~= nil) then print('</A>') end

  print [[
	    <script type="text/javascript">

	    var opts = {
	    fontSize: 40,
	    lines: 12, // The number of lines to draw
	    angle: 0.15, // The length of each line
	    lineWidth: 0.44, // The line thickness
	    pointer: {
	       length: 0.85, // The radius of the inner circle
	       strokeWidth: 0.051, // The rotation offset
	       color: '#000000' // Fill color
	    },
	    limitMax: 'false',   // If true, the pointer will not go past the end of the gauge

	 colorStart: '#6FADCF',   // Colors
	 colorStop: '#8FC0DA',    // just experiment with them
	 strokeColor: '#E0E0E0',   // to see which ones work best for you
	 generateGradient: true
      };
   ]]

  print('var target = document.getElementById("'..name..'"); // your canvas element\n')
  print('var '..name..' = new Gauge(target).setOptions(opts);\n')
  --print(name..'.setTextField(document.getElementById("'..name..'-text"));\n')
  print(name..'.maxValue = '..maxValue..'; // set max gauge value\n')
  print("</script>\n")
end

-- Compute the difference in seconds between local time and UTC.
function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
end


function isLocal(host_ip)
  host = interface.getHostInfo(host_ip)

  if((host == nil) or (host['localhost'] ~= true)) then
    return(false)
  else
    return(true)
  end
end

-- Return the first 'howmany' hosts
function getTopInterfaceHosts(howmany, localHostsOnly)
  hosts_stats,total = aggregateHostsStats(interface.getHostsInfo())
  ret = {}
  sortTable = {}
  n = 0
  for k,v in pairs(hosts_stats) do
    if((not localHostsOnly) or ((v["localhost"] == true) and (v["ip"] ~= nil))) then
      sortTable[v["bytes.sent"]+v["bytes.rcvd"]+n] = k
      n = n +0.01
    end
  end

  n = 0
  for _v,k in pairsByKeys(sortTable, rev) do
    if(n < howmany) then
      ret[k] = hosts_stats[k]
      n = n+1
    else
      break
    end
  end

  return(ret)
end

function http_escape(s)
  s = string.gsub(s, "([&=+%c])", function (c)
    return string.format("%%%02X", string.byte(c))
  end)
  s = string.gsub(s, " ", "+")
  return s
end

function getInterfaceId(interface_name)
  ifnames = interface.getIfNames()

  for _,if_name in pairs(ifnames) do
     interface.select(if_name)
     _ifstats = aggregateInterfaceStats(interface.getStats())
    if(_ifstats.name == interface_name) then return(_ifstats.id) end
  end

  return(-1)
end

-- Windows fixes for interfaces with "uncommon chars"
function purifyInterfaceName(interface_name)
  -- io.write(debug.traceback().."\n")
  interface_name = string.gsub(interface_name, "@", "_")
  interface_name = string.gsub(interface_name, ":", "_")
  interface_name = string.gsub(interface_name, "/", "_")
  return(interface_name)
end

-- Fix path format Unix <-> Windows
function fixPath(path)
   if(ntop.isWindows() and (string.len(path) > 2)) then
      path = string.gsub(path, "/", "\\")
      -- Avoid changing c:\.... into c_\....
      path = string.sub(path, 1, 2) .. string.gsub(string.sub(path, 3), ":", "_")
      -- io.write("->"..path.."\n")
   end

  return(path)
end

-- See datatype AggregationType in ntop_typedefs.h
function aggregation2String(value)
  if(value == 0) then return("Client Name")
  elseif(value == 1) then return("Server Name")
  elseif(value == 2) then return("Domain Name")
  elseif(value == 3) then return("Operating System")
  elseif(value == 4) then return("Registrar Name")
  else return(value)
  end
end

function getOSIcon(name)
  icon = ""

  if(findString(name, "Linux") or findString(name, "Ubuntu")) then icon = '<i class=\'fa fa-linux fa-lg\'></i> '
  elseif(findString(name, "Android")) then icon = '<i class=\'fa fa-android fa-lg\'></i> '
  elseif(findString(name, "Windows") or findString(name, "Win32") or findString(name, "MSIE")) then icon = '<i class=\'fa fa-windows fa-lg\'></i> '
  elseif(findString(name, "iPhone") or findString(name, "iPad") or findString(name, "OS X") ) then icon = '<i class=\'fa fa-apple fa-lg\'></i> '
  end

  return(icon)
end

function getApplicationLabel(name)
  icon = ""

  if(name == nil) then name = "" end

  if(findString(name, "Skype")) then icon = '<i class=\'fa fa-skype fa-lg\'></i>'
  elseif(findString(name, "Unknown")) then icon = '<i class=\'fa fa-question fa-lg\'></i>'
  elseif(findString(name, "Twitter")) then icon = '<i class=\'fa fa-twitter fa-lg\'></i>'
  elseif(findString(name, "DropBox")) then icon = '<i class=\'fa fa-dropbox fa-lg\'></i>'
  elseif(findString(name, "Spotify")) then icon = '<i class=\'fa fa-spotify fa-lg\'></i>'
  elseif(findString(name, "Apple")) then icon = '<i class=\'fa fa-apple fa-lg\'></i>'
  elseif(findString(name, "Google") or
    findString(name, "Chrome")) then icon = '<i class=\'fa fa-google-plus fa-lg\'></i>'
  elseif(findString(name, "FaceBook")) then icon = '<i class=\'fa fa-facebook-square fa-lg\'></i>'
  elseif(findString(name, "Youtube")) then icon = '<i class=\'fa fa-youtube-square fa-lg\'></i>'
  elseif(findString(name, "thunderbird")) then icon = '<i class=\'fa fa-paper-plane fa-lg\'></i>'
  end

  name = name:gsub("^%l", string.upper)
  return(icon.." "..name)
end

function mapOS2Icon(name)
  if(name == nil) then
    return("")
  else
    return(getOSIcon(name) .. name)
  end
end

function getItemsNumber(n)
  tot = 0
  for k,v in pairs(n) do
    --io.write(k.."\n")
    tot = tot + 1
  end

  --io.write(tot.."\n")
  return(tot)
end

function getHostCommaSeparatedList(p_hosts)
  hosts = {}
  hosts_size = 0
  for i,host in pairs(split(p_hosts, ",")) do
    hosts[i] = host
    hosts_size = hosts_size + 1
  end
  return hosts,hosts_size
end

-- ##############################################

-- Used to avoid resolving host names too many times
resolved_host_labels_cache = {}

function getHostAltName(host_ip)
   local alt_name = resolved_host_labels_cache[host_ip]

   if(alt_name ~= nil) then
      return(alt_name)
   end

   alt_name = ntop.getHashCache("ntopng.host_labels", host_ip)

   if((alt_name == nil) or (alt_name == "")) then
     alt_name = host_ip
   end

   resolved_host_labels_cache[host_ip] = alt_name

   return(alt_name)
end

function setHostAltName(host_ip, alt_name)
  ntop.setHashCache("ntopng.host_labels", host_ip, alt_name)
end

-- Flow Utils --

function host2name(name, vlan)
   local orig_name = name

   vlan = tonumber(vlan or "0")

   name = getHostAltName(name)

   if(name == orig_name) then
      rname = ntop.getResolvedAddress(name)

      if((rname ~= nil) and (rname ~= "")) then
	 name = rname
      end
   end

   if(vlan > 0) then
      name = name .. '@' .. vlan
   end

   return name
end


function flowinfo2hostname(flow_info, host_type, vlan)
   local name
   local orig_name

   if(host_type == "srv") then
      if(flow_info["host_server_name"] ~= nil) then return(flow_info["host_server_name"]) end
      if(flow_info["protos.ssl.certificate"] ~= nil)  then return(flow_info["protos.ssl.certificate"]) end
   end

   name = flow_info[host_type..".host"]

   if((name == "") or (name == nil)) then
      name = flow_info[host_type..".ip"]
   end

   return(host2name(name, flow_info["vlan"]))
end


-- URL Util --

--
-- Split the host key (ip@vlan) creating a new lua table.
-- Example:
--    info = hostkey2hostinfo(key)
--    ip = info["host"]
--    vlan = info["vlan"]
--
function hostkey2hostinfo(key)
  local host = {}
  local info = split(key,"@")
  if(info[1] ~= nil) then host["host"] = info[1]           end
  if(info[2] ~= nil) then
    host["vlan"] = tonumber(info[2])
  else
    host["vlan"] = 0
  end
  return host
end

--
-- Analyze the host_info table and return the host key.
-- Example:
--    host_info = interface.getHostInfo("127.0.0.1",0)
--    key = hostinfo2hostkey(host_info)
--
function hostinfo2hostkey(host_info,host_type,show_vlan)
  local rsp = ""

  if(host_type == "cli") then

    if(host_info["cli.ip"] ~= nil) then
      rsp = rsp..host_info["cli.ip"]
    end

  elseif(host_type == "srv") then

    if(host_info["srv.ip"] ~= nil) then
      rsp = rsp..host_info["srv.ip"]
    end
  else

    if(host_info["host"] ~= nil) then
      rsp = rsp..host_info["host"]
    elseif(host_info["name"] ~= nil) then
      rsp = rsp..host_info["name"]
    elseif(host_info["ip"] ~= nil) then
      rsp = rsp..host_info["ip"]
    elseif(host_info["mac"] ~= nil) then
      rsp = rsp..host_info["mac"]
    end
  end

  if(((host_info["vlan"] ~= nil) and (host_info["vlan"] ~= 0))
     or ((show_vlan ~= nil) and show_vlan))  then
    rsp = rsp..'@'..tostring(host_info["vlan"])
  end

  if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"HOST2URL => ".. rsp .. "\n") end
  return rsp
end

--
-- Analyze the get_info and return a new table containing the url information about an host.
-- Example: url2host(_GET)
--
function url2hostinfo(get_info)
  local host = {}

  -- Catch when the host key is using as host url parameter
  if((get_info["host"] ~= nil) and (string.find(get_info["host"],"@"))) then
    get_info = hostkey2hostinfo(get_info["host"])
  end

  if(get_info["host"] ~= nil) then
    host["host"] = get_info["host"]
    if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"URL2HOST => Host:"..get_info["host"].."\n") end
  end

  if(get_info["vlan"] ~= nil) then
    host["vlan"] = tonumber(get_info["vlan"])
    if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"URL2HOST => Vlan:"..get_info["vlan"].."\n") end
  else
    host["vlan"] = 0
  end

  return host
end

--
-- Catch the main information about an host from the host_info table and return the corresponding url.
-- Example:
--          hostinfo2url(host_key), return an url based on the host_key
--          hostinfo2url(host[key]), return an url based on the host value
--          hostinfo2url(flow[key],"cli"), return an url based on the client host information in the flow table
--          hostinfo2url(flow[key],"srv"), return an url based on the server host information in the flow table
--

function hostinfo2url(host_info,host_type)
  local rsp = ''
  -- local version = 0
  local version = 1

  if(host_type == "cli") then

    if(host_info["cli.ip"] ~= nil) then
      rsp = rsp..'host='..host_info["cli.ip"]
    end

  elseif(host_type == "srv") then
    if(host_info["srv.ip"] ~= nil) then
      rsp = rsp..'host='..host_info["srv.ip"]
    end
  else

    if((type(host_info) ~= "table")) then
      host_info = hostkey2hostinfo(host_info)
    end

    if(host_info["host"] ~= nil) then
      rsp = rsp..'host='..host_info["host"]
    elseif(host_info["ip"] ~= nil) then
      rsp = rsp..'host='..host_info["ip"]
    elseif(host_info["name"] ~= nil) then
      rsp = rsp..'host='..host_info["name"]
    elseif(host_info["mac"] ~= nil) then
      rsp = rsp..'host='..host_info["mac"]
    end

  end

  if((host_info["vlan"] ~= nil) and (host_info["vlan"] ~= 0)) then
    if(version == 0) then
      rsp = rsp..'&vlan='..tostring(host_info["vlan"])
    elseif(version == 1) then
      rsp = rsp..'@'..tostring(host_info["vlan"])
    end
  end

  if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"HOST2URL => ".. rsp .. "\n") end

  return rsp
end


--
-- Catch the main information about an host from the host_info table and return the corresponding json.
-- Example:
--          hostinfo2json(host[key]), return a json string based on the host value
--          hostinfo2json(flow[key],"cli"), return a json string based on the client host information in the flow table
--          hostinfo2json(flow[key],"srv"), return a json string based on the server host information in the flow table
--
function hostinfo2json(host_info,host_type)
  local rsp = ''

  if(host_type == "cli") then
    if(host_info["cli.ip"] ~= nil) then
      rsp = rsp..'host: "'..host_info["cli.ip"]..'"'
    end
  elseif(host_type == "srv") then
    if(host_info["srv.ip"] ~= nil) then
      rsp = rsp..'host: "'..host_info["srv.ip"]..'"'
    end
  else
    if((type(host_info) ~= "table") and (string.find(host_info,"@"))) then
      host_info = hostkey2hostinfo(host_info)
    end

    if(host_info["host"] ~= nil) then
      rsp = rsp..'host: "'..host_info["host"]..'"'
    elseif(host_info["ip"] ~= nil) then
      rsp = rsp..'host: "'..host_info["ip"]..'"'
    elseif(host_info["name"] ~= nil) then
      rsp = rsp..'host: "'..host_info["name"] ..'"'
    elseif(host_info["mac"] ~= nil) then
      rsp = rsp..'host: "'..host_info["mac"] ..'"'
    end
  end

  if((host_info["vlan"] ~= nil) and (host_info["vlan"] ~= 0)) then
    rsp = rsp..', vlan: "'..tostring(host_info["vlan"]) .. '"'
  end

  if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"HOST2JSON => ".. rsp .. "\n") end

  return rsp
end

--
-- Catch the main information about an host from the host_info table and return the corresponding jqueryid.
-- Example: host 192.168.1.254, vlan0  ==> 1921681254_0
function hostinfo2jqueryid(host_info,host_type)
  local rsp = ''

  if(host_type == "cli") then
    if(host_info["cli.ip"] ~= nil) then
      rsp = rsp..''..host_info["cli.ip"]
    end

  elseif(host_type == "srv") then
    if(host_info["srv.ip"] ~= nil) then
      rsp = rsp..''..host_info["srv.ip"]
    end
  else
    if((type(host_info) ~= "table") and (string.find(host_info,"@"))) then
      host_info = hostkey2hostinfo(host_info)
    end

    if(host_info["host"] ~= nil) then
      rsp = rsp..''..host_info["host"]
    elseif(host_info["ip"] ~= nil) then
      rsp = rsp..''..host_info["ip"]
    elseif(host_info["name"] ~= nil) then
      rsp = rsp..''..host_info["name"]
    elseif(host_info["mac"] ~= nil) then
      rsp = rsp..''..host_info["mac"]
    end
  end


  if((host_info["vlan"] ~= nil) and (host_info["vlan"] ~= 0)) then
    rsp = rsp..'@'..tostring(host_info["vlan"])
  end

  rsp = string.gsub(rsp, "%.", "__")
  rsp = string.gsub(rsp, "/", "___")
  rsp = string.gsub(rsp, ":", "____")

  if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"HOST2KEY => ".. rsp .. "\n") end

  return rsp
end

-- version is major.minor.veryminor
function version2int(v)
   if(v == nil) then return(0) end

  e = string.split(v, "%.");
  if(e ~= nil) then
    major = e[1]
    minor = e[2]
    veryminor = e[3]

    if(major == nil or tonumber(major) == nil or type(major) ~= "string")     then major = 0 end
    if(minor == nil or tonumber(minor) == nil or type(minor) ~= "string")     then minor = 0 end
    if(veryminor == nil or tonumber(veryminor) == nil or type(veryminor) ~= "string") then veryminor = 0 end

    version = tonumber(major)*1000 + tonumber(minor)*100 -- + tonumber(veryminor)
    return(version)
  else
    return(0)
  end
end

function ntop_version_check()
   _rsp = ntop.getCache("ntopng.version")

   if((_rsp == nil) or (_rsp == "")) then
      _rsp = ntop.httpGet("http://www.ntop.org/ntopng.version", "", "", 10)
      if((_rsp == nil) or (_rsp["CONTENT"] == nil)) then rsp = "0.0.0" else rsp = _rsp["CONTENT"] end
      ntop.setCache("ntopng.version", rsp, 86400)
   else
      rsp = _rsp
   end

   if(rsp ~= nil) then
      info = ntop.getInfo(false)
      new_version = version2int(rsp)

      version_elems  = split(info["version"], " ");
      this_version   = version2int(version_elems[1])

      if(new_version > this_version) then
	 print("<p><div class=\"alert alert-warning\"><font color=red><i class=\"fa fa-cloud-download fa-lg\"></i> A new "..info["product"].." (v." .. rsp .. ") is available for <A HREF=http://www.ntop.org/get-started/download/>download</A>: please upgrade.</font></div></p>")
      end
   end
end


-- Print contents of `tbl`, with indentation.
-- You can call it as tprint(mytable)
-- The other two parameters should not be set
function tprint(s, l, i)
   l = (l) or 1000; i = i or "";-- default item limit, indent string
   if (l<1) then io.write("ERROR: Item limit reached.\n"); return l-1 end;
   local ts = type(s);
   if (ts ~= "table") then io.write(i..' '..ts..' '..tostring(s)..'\n'); return l-1 end
   io.write(i..' '..ts..'\n');
   for k,v in pairs(s) do
      local indent = ""

      if(i ~= "") then
	 indent = i .. "."
      end
      indent = indent .. tostring(k)

      l = tprint(v, l, indent);
      if (l < 0) then break end
   end

   return l
end

function table.empty(table)
  if(table == nil) then return true end
  if next(table) == nil then
    return true
  end
  return false
end

function table.len(table)
 local count = 0

  if(table == nil) then return(0) end
  for k,v in pairs(table) do
    count = count + 1
  end

  return count
end

function table.slice(tbl, first, last, step)
   local sliced = {}

   for i = first or 1, last or #tbl, step or 1 do
      sliced[#sliced+1] = tbl[i]
   end

   return sliced
end

-- ############################################
-- Redis Utils
-- ############################################

-- Inpur:     General prefix (i.e ntopng.pref)
-- Output:  User based prefix, if it exists
--
-- Examples:
--                With user:  ntopng.pref.user_name
--                Without:    ntopng.pref
function getRedisPrefix(str)
  if not (isEmptyString(_SESSION["user"] )) then
    -- Login enabled
    return (str .. '.' .. _SESSION["user"])
  else
    -- Login disabled
    return (str)
  end
end

function getPathFromKey(key)
  local path = string.gsub(key, "%.", "/")
  path = string.gsub(path, ":", "_")
  return fixPath(path)
end

-----  End of Redis Utils  ------


function isPausedInterface(current_ifname)
  state = ntop.getCache("ntopng.prefs."..current_ifname.."_not_idle")
  if(state == "0") then return true else return false end
end

function getThroughputType()
  throughput_type = ntop.getCache("ntopng.prefs.thpt_content")

  if(throughput_type == "") then
    throughput_type = "bps"
  end
  return throughput_type
end

function isLoopback(name)
  if((name == "lo") or (name == "lo0")) then
    return(true)
  else
    return(false)
  end
end

function isLocalPacketdumpEnabled()
   local nbox_integration = ntop.getCache("ntopng.prefs.nbox_integration")
   if nbox_integration == nil or nbox_integration ~= "1" then
      nbox_integration = false
   else
      nbox_integration = true
   end
   return isAdministrator() and not nbox_integration and not interface.isView() and interface.isPacketInterface()
end

function processColor(proc)
  if(proc == nil) then
    return("")
  elseif(proc["average_cpu_load"] < 33) then
    return("<font color=green>"..proc["name"].."</font>")
  elseif(proc["average_cpu_load"] < 66) then
    return("<font color=orange>"..proc["name"].."</font>")
  else
    return("<font color=red>"..proc["name"].."</font>")
  end
end

 -- Table preferences

function getDefaultTableSort(table_type)
   table_key = getRedisPrefix("ntopng.prefs.table")
  if(table_type ~= nil) then
     value = ntop.getHashCache(table_key, "sort_"..table_type)
  end
  if((value == nil) or (value == "")) then value = 'column_' end
  return(value)
end

function getDefaultTableSortOrder(table_type)
  table_key = getRedisPrefix("ntopng.prefs.table")
  if(table_type ~= nil) then
    value = ntop.getHashCache(table_key, "sort_order_"..table_type)
  end
  if((value == nil) or (value == "")) then value = 'desc' end
  return(value)
end

function getDefaultTableSize()
  table_key = getRedisPrefix("ntopng.prefs.table")
  value = ntop.getHashCache(table_key, "rows_number")
  if((value == nil) or (value == "")) then value = 10 end
  return(tonumber(value))
end

function tablePreferences(key, value)
  table_key = getRedisPrefix("ntopng.prefs.table")
  if((value == nil) or (value == "")) then
    -- Get preferences
    return ntop.getHashCache(table_key, key)
  else
    -- Set preferences
    ntop.setHashCache(table_key, key, value)
    return(value)
  end
end


function getInterfaceNameAlias(interface_name)
   -- io.write(debug.traceback().."\n")
   label = ntop.getCache('ntopng.prefs.'..interface_name..'.name')
   if((label == nil) or (label == "")) then
      return(interface_name)
   else
      return(label)
   end
end

function getHumanReadableInterfaceName(interface_name)
   key = 'ntopng.prefs.'..interface_name..'.name'
   custom_name = ntop.getCache(key)

   if((custom_name ~= nil) and (custom_name ~= "")) then
      return(custom_name)
   else
      interface.select(interface_name)
      _ifstats = aggregateInterfaceStats(interface.getStats())

      -- print(interface_name.."=".._ifstats.name)
      return(_ifstats.name)
   end
end

-- ##############################################

function escapeHTML(s)
   s = string.gsub(s, "([&=+%c])", function (c)
				      return string.format("%%%02X", string.byte(c))
				   end)
   s = string.gsub(s, " ", "+")
   return s
end

-- ##############################################

function unescapeHTML (s)
   s = string.gsub(s, "+", " ")
   s = string.gsub(s, "%%(%x%x)", function (h)
				     return string.char(tonumber(h, 16))
				  end)
   return s
end

-- ##############################################

function harvestUnusedDir(path, min_epoch)
   local files = ntop.readdir(path)

   -- print("Reading "..path.."<br>\n")

   for k,v in pairs(files) do
      if(v ~= nil) then
	 local p = fixPath(path .. "/" .. v)
	 if(ntop.isdir(p)) then
	    harvestUnusedDir(p, min_epoch)
	 else
	    local when = ntop.fileLastChange(path)

	    if((when ~= -1) and (when < min_epoch)) then
	       os.remove(p)
	    end
	 end
      end
   end
end

 -- ##############################################

function harvestJSONTopTalkers(days)
   local when = os.time() - 86400 * days

   ifnames = interface.getIfNames()
   for _,ifname in pairs(ifnames) do
      interface.select(ifname)
      local _ifstats = aggregateInterfaceStats(interface.getStats())
      local dirs = ntop.getDirs()
      local basedir = fixPath(dirs.workingdir .. "/" .. _ifstats.id)

      harvestUnusedDir(fixPath(basedir .. "/top_talkers"), when)
      harvestUnusedDir(fixPath(basedir .. "/flows"), when)
   end
end

 -- ##############################################

function isAdministrator()
   local user_group = ntop.getUserGroup()

   if(user_group == "administrator") then
      return(true)
   else
      return(false)
   end
end

 -- ##############################################

function haveAdminPrivileges()
   if(isAdministrator) then
      return(true)
   else
      ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
      dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
      print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Access forbidden</div>")
      return(false)
   end
end

 -- ##############################################

function getKeysSortedByValue(tbl, sortFunction)
  local keys = {}
  for key in pairs(tbl) do
    table.insert(keys, key)
  end

  table.sort(keys, function(a, b)
    return sortFunction(tbl[a], tbl[b])
  end)

  return keys
end

function getKeys(t, col)
  local keys = {}
  for k,v in pairs(t) do keys[tonumber(v[col])] = k end
  return keys
end

 -- ##############################################

function formatBreed(breed)
   if(breed == "Safe") then
      return("<i class='fa fa-lock' alt='Safe Protocol'></i>")
   elseif(breed == "Acceptable") then
      return("<i class='fa fa-thumbs-o-up' alt='Acceptable Protocol'></i>")
   elseif(breed == "Fun") then
      return("<i class='fa fa-smile-o' alt='Fun Protocol'></i>")
   elseif(breed == "Unsafe") then
      return("<i class='fa fa-thumbs-o-down'></i>")
   elseif(breed == "Dangerous") then
      return("<i class='fa fa-warning'></i>")
   else
      return("")
   end
end

function getFlag(country)
   if((country == nil) or (country == "")) then
      return("")
   else
      return(" <A HREF=" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country=".. country .."><img src='".. ntop.getHttpPrefix() .. "/img/blank.gif' class='flag flag-".. string.lower(country) .."'></A> ")
   end
end

-- GENERIC UTILS

-- ternary
function ternary(cond, T, F)
   if cond then return T else return F end
end

-- split
function split(s, delimiter)
   result = {};
   for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
    end
    return result;
end

-- startswith
function startswith(s, char)
   return string.sub(s, 1, string.len(s)) == char
end

-- strsplit

function strsplit(s, delimiter)
   result = {};
   for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      if(match ~= "") then result[match] = true end
   end
    return result;
end

-- isempty
function isempty(array)
  local count = 0
  for _,__ in pairs(array) do
    count = count + 1
  end
  return (count == 0)
end

-- isin
function isin(s, array)
  if (s == nil or s == "" or array == nil or isempty(array)) then return false end
  for _, v in pairs(array) do
    if (s == v) then return true end
  end
  return false
end

-- hasKey
function hasKey(key, theTable)
   if((theTable == nil) or (theTable[key] == nil)) then
      return(false)
   else
      return(true)
   end
end

-- maxRateToString
function maxRateToString(max_rate)
   if((max_rate == nil) or (max_rate == "")) then max_rate = -1 end
   max_rate = tonumber(max_rate)
   if(max_rate == -1) then
      return("No Limit")
   else
      if(max_rate == 0) then
	 return("Drop All Traffic")
      else
	 if(max_rate < 1000) then
	    return(max_rate.." Kbit/s")
	 else
	    local mr
	    mr = round(max_rate / 1000, 2)

	    if(mr < 1000) then
	       return(mr.." Mbit/s")
	    else
	       gbit = mr /1000
	       return(gbit.." Gbit/s")
	    end
	 end
      end
   end
end

-- makeTopStatsScriptsArray
function makeTopStatsScriptsArray()
   path = dirs.installdir .. "/scripts/lua/modules/top_scripts"
   path = fixPath(path)
   local files = ntop.readdir(path)
   topArray = {}

   for k,v in pairs(files) do
      if(string.ends(k, ".lua")) then
	 if(v ~= nil) then
	    value = {}
	    fn,ext = v:match("([^.]+).([^.]+)")
	    mod = require("top_scripts."..fn)
	    if(type(mod) ~= type(true)) then
	       value["name"] = mod.name
	       value["script"] = mod.infoScript
	       value["key"] = mod.infoScriptKey
	       value["levels"] = mod.numLevels
	       topArray[fn] = value
	    end
	 end
      end
   end

   return(topArray)
end

local mac_cache = { }
-- get_mac_classification
function get_mac_classification(m)
   local path = fixPath(dirs.installdir.."/httpdocs/other/EtherOUI.txt")
   local file_mac

   if(string.len(m) > 8) then m = string.sub(m, 1, 8) end

   if(mac_cache[m] ~= nil) then
      -- io.write("Cached "..m.."\n")
      return(mac_cache[m])
   end

   file_mac = io.open(path)
   if (file_mac == nil) then return m end

   local mac_line = file_mac:read("*l")
   while (mac_line ~= nil) do
      if (not startswith(mac_line, "#") and mac_line ~= "") then
	 b = string.sub(mac_line, 1, 8)
	 if (m == b) then
	   t = split(mac_line, "\t")
	   file_mac.close()
	   rsp = split(t[2], " ")[1]
	   mac_cache[m] = rsp
	   return rsp
	end
      end
      mac_line = file_mac:read("*l")
   end
   file_mac.close()

   return m
end

local magic_macs = {
   ["FF:FF:FF:FF:FF:FF"] = "Broadcast",
   ["01:00:0C:CC:CC:CC"] = "CDP",
   ["01:00:0C:CC:CC:CD"] = "CiscoSTP",
   ["01:80:C2:00:00:00"] = "STP",
   ["01:80:C2:00:00:00"] = "LLDP",
   ["01:80:C2:00:00:03"] = "LLDP",
   ["01:80:C2:00:00:0E"] = "LLDP",
   ["01:80:C2:00:00:08"] = "STP",
   ["01:1B:19:00:00:00"] = "PTP",
   ["01:80:C2:00:00:0E"] = "PTP"
}

local magic_short_macs = {
   ["01:00:5E"] = "IPv4mcast",
   ["33:33:"] = "IPv6mcast"
}

-- get_symbolic_mac
function get_symbolic_mac(mac_address)
   if(magic_macs[mac_address] ~= nil) then
      return(magic_macs[mac_address])
   else
      local m = string.sub(mac_address, 1, 8)
      local t = string.sub(mac_address, 10, 17)

      if(magic_short_macs[m] ~= nil) then
	 return(magic_short_macs[m].."_"..t.." ("..mac_address..")")
      else
	 local s = get_mac_classification(m)

	 if(m == s) then
	    return(get_mac_classification(m)..":"..t)
	 else
	    return(get_mac_classification(m).."_"..t.." ("..mac_address..")")
	 end
      end
   end
end

-- rrd_exists
function rrd_exists(host_ip, rrdname)
if(host_ip == nil) then return false end
   dirs = ntop.getDirs()
   rrdpath = dirs.workingdir .. "/" .. ifId .. "/rrd/" .. getPathFromKey(host_ip) .. "/" .. rrdname
   return ntop.exists(rrdpath)
end

-- getservbyport
function getservbyport(port_num, proto)
   if(proto == nil) then proto = "TCP" end

   port_num = tonumber(port_num)

   proto = string.lower(proto)

   -- io.write(port_num.."@"..proto.."\n")
   return(ntop.getservbyport(port_num, proto))
end

-- getSpeedMax
function getSpeedMax(ifname)

   if(ifname == nil) then
      return -1
   end

   if(ifname ~= "eth0") then
      return -1
   end

   ifname = tostring(ifname)

   return(ntop.getSpeedMax(ifname))
end

function intToIPv4(num)
   return(math.floor(num / 2^24).. "." ..math.floor((num % 2^24) / 2^16).. "." ..math.floor((num % 2^16) / 2^8).. "." ..num % 2^8)
end

function getFlowMaxRate(cli_max_rate, srv_max_rate)
   cli_max_rate = tonumber(cli_max_rate)
   srv_max_rate = tonumber(srv_max_rate)

   if((cli_max_rate == 0) or (srv_max_rate == 0)) then
      max_rate = 0
      elseif((cli_max_rate == -1) and (srv_max_rate > 0)) then
      max_rate = srv_max_rate
      elseif((cli_max_rate > 0) and (srv_max_rate == -1)) then
      max_rate = cli_max_rate
   else
      max_rate = math.min(cli_max_rate, srv_max_rate)
   end

   return(max_rate)
end

-- ###############################################

function tolongint(what)
   if(what == nil) then
      return(0)
   else
      return(string.format("%u", what))
   end
end

-- ###############################################

function trimSpace(what)
   if(what == nil) then return("") end
   return(string.gsub(what, "%s+", ""))
end

-- ###############################################

function formatWebSite(site)
   return("<A target=\"_blank\" HREF=http://"..site..">"..site.."</A> <i class=\"fa fa-external-link\"></i></th>")
end

-- Update Utils::flowstatus2str
function getFlowStatus(status)
  if(status == 0) then return("<font color=green>Normal</font>")
  elseif(status == 1) then return("<font color=orange>Slow TCP Connection</font>")
  elseif(status == 2) then return("<font color=orange>Slow Application Header</font>")
  elseif(status == 3) then return("<font color=orange>Slow Data Exchange (Slowloris?)</font>")
  elseif(status == 4) then return("<font color=orange>Low Goodput</font>")
  elseif(status == 5) then return("<font color=orange>Suspicious TCP SYN Probing (or server port down)</font>")
  elseif(status == 6) then return("<font color=orange>TCP Connection Reset</font>")
  elseif(status == 7) then return("<font color=orange>Suspicious TCP Probing</font>")
  else return("<font color=orange>Unknown status ("..status..")</font>")
  end
end

-- prints purged information for hosts / flows
function purgedErrorString()
    return 'Very likely it is expired and ntopng has purged it from memory. You can set purge idle timeout settings from the <A HREF="'..ntop.getHttpPrefix()..'/lua/admin/prefs.lua?subpage_active=data_purge"><i class="fa fa-flask"></i> Preferences</A>.'
end

-- print TCP flags
function printTCPFlags(flags)
   if(hasbit(flags,0x01)) then print('<span class="label label-info">FIN</span> ') end
   if(hasbit(flags,0x02)) then print('<span class="label label-info">SYN</span> ')  end
   if(hasbit(flags,0x04)) then print('<span class="label label-danger">RST</span> ') end
   if(hasbit(flags,0x08)) then print('<span class="label label-info">PUSH</span> ') end
   if(hasbit(flags,0x10)) then print('<span class="label label-info">ACK</span> ')  end
   if(hasbit(flags,0x20)) then print('<span class="label label-info">URG</span> ')  end
end

-- convert the integer carrying TCP flags in a more conventient lua table
function TCPFlags2table(flags)
   local res = {["FIN"] = 0, ["SYN"] = 0, ["RST"] = 0, ["PSH"] = 0, ["ACK"] = 0, ["URG"] = 0}
   if(hasbit(flags,0x01)) then res["FIN"] = 1 end
   if(hasbit(flags,0x02)) then res["SYN"] = 1 end
   if(hasbit(flags,0x04)) then res["RST"] = 1 end
   if(hasbit(flags,0x08)) then res["PSH"] = 1 end
   if(hasbit(flags,0x10)) then res["ACK"] = 1 end
   if(hasbit(flags,0x20)) then res["URG"] = 1 end
   return res
end

-- ##########################################

function historicalProtoHostHref(ifId, host, l4_proto, ndpi_proto_id, info)
   if ntop.isPro() and ntop.getPrefs().is_dump_flows_to_mysql_enabled == true then
      local hist_url = ntop.getHttpPrefix().."/lua/pro/db_explorer.lua?search=true&ifId="..ifId
      local now    = os.time()
      local ago1h  = now - 3600

      hist_url = hist_url.."&epoch_end="..tostring(now)
      if((host ~= nil) and (host ~= "")) then hist_url = hist_url.."&"..hostinfo2url(host) end
      if((l4_proto ~= nil) and (l4_proto ~= "")) then
	 hist_url = hist_url.."&l4proto="..l4_proto
      end
      if((ndpi_proto_id ~= nil) and (ndpi_proto_id ~= "")) then hist_url = hist_url.."&protocol="..ndpi_proto_id end
      if((info ~= nil) and (info ~= "")) then hist_url = hist_url.."&info="..info end
      print('&nbsp;')
      -- print('<span class="label label-info">')
      print('<a href="'..hist_url..'&epoch_begin='..tostring(ago1h)..'" title="Flows seen in the last hour"><i class="fa fa-history fa-lg"></i></a>')
      -- print('</span>')
   end
end

-- ##########################################

_icmp_types = {
	 { 0, 0, "Echo Reply" },
	 { 3, 0, "Network Unreachable" },
	 { 3, 1, "Host Unreachable" },
	 { 3, 2, "Protocol Unreachable" },
	 { 3, 3, "Port Unreachable" },
	 { 3, 4, "Fragmentation needed but no fragment bit set" },
	 { 3, 5, "Source routing failed" },
	 { 3, 6, "Destination network unknown" },
	 { 3, 7, "Destination host unknown" },
	 { 3, 8, "Source host isolated (obsolete)" },
	 { 3, 9, "Destination network administratively prohibited" },
	 { 3, 10, "Destination host administratively prohibited" },
	 { 3, 11, "Network unreachable for TOS" },
	 { 3, 12, "Host unreachable for TOS" },
	 { 3, 13, "Communication administratively prohibited by filtering" },
	 { 3, 14, "Host precedence violation" },
	 { 3, 15, "Precedence cutoff in effect" },
	 { 4, 0, "Source quench" },
	 { 5, 0, "Redirect for network" },
	 { 5, 1, "Redirect for host" },
	 { 5, 2, "Redirect for TOS and network" },
	 { 5, 3, "Redirect for TOS and host" },
	 { 8, 0, "Echo request x" },
	 { 9, 0, "Router advertisement" },
	 { 10, 0, "Route solicitation" },
	 { 11, 0, "TTL equals 0 during transit" },
	 { 11, 1, "TTL equals 0 during reassembly" },
	 { 12, 0, "IP header bad (catchall error)" },
	 { 12, 1, "Required options missing" },
	 { 13, 0, "Timestamp request (obsolete)" },
	 { 14, 0, "Timestamp reply (obsolete)" },
	 { 15, 0, "Information request (obsolete)" },
	 { 16, 0, "Information reply (obsolete)" },
	 { 17, 0, "Address mask request" },
	 { 18, 0, "Address mask reply" }
}

-- Code is currently ignored on IVMPv6
_icmpv6_types = {
        { 0, "Reserved" },
	{ 1, "Destination Unreachable" },
	{ 2, "Packet Too Big" },
	{ 3, "Time Exceeded" },
	{ 4, "Parameter Problem" },
	{ 100, "Private experimentation" },
	{ 101, "Private experimentation" },
	-- { 102-126, "Unassigned" },
	{ 127, "Reserved for expansion of ICMPv6 error messages" },
	{ 128, "Echo Request" },
	{ 129, "Echo Reply" },
	{ 130, "Multicast Listener Query" },
	{ 131, "Multicast Listener Report" },
	{ 132, "Multicast Listener Done" },
	{ 133, "Router Solicitation" },
	{ 134, "Router Advertisement" },
	{ 135, "Neighbor Solicitation" },
	{ 136, "Neighbor Advertisement" },
	{ 137, "Redirect Message" },
	{ 138, "Router Renumbering" },
	{ 139, "ICMP Node Information Query" },
	{ 140, "ICMP Node Information Response" },
	{ 141, "Inverse Neighbor Discovery Solicitation Message" },
	{ 142, "Inverse Neighbor Discovery Advertisement Message" },
	{ 143, "Version 2 Multicast Listener Report" },
	{ 144, "Home Agent Address Discovery Request Message" },
	{ 145, "Home Agent Address Discovery Reply Message" },
	{ 146, "Mobile Prefix Solicitation" },
	{ 147, "Mobile Prefix Advertisement" },
	{ 148, "Certification Path Solicitation Message" },
	{ 149, "Certification Path Advertisement Message" },
	{ 150, "ICMP messages utilized by experimental mobility protocols" },
	{ 151, "Multicast Router Advertisement" },
	{ 152, "Multicast Router Solicitation" },
	{ 153, "Multicast Router Termination" },
	{ 154, "FMIPv6 Messages" },
	{ 155, "RPL Control Message" },
	{ 156, "ILNPv6 Locator Update Message" },
	{ 157, "Duplicate Address Request" },
	{ 158, "Duplicate Address Confirmation" },
	{ 159, "MPL Control Message" },
	-- { 160-199, "Unassigned" },
	{ 200, "Private experimentation" },
	{ 201, "Private experimentation" },
	{ 255, "Reserved for expansion of ICMPv6 informational messages" }
}

-- #############################################

function getICMPV6TypeCode(icmp)
  local t = icmp.type
  local c = icmp.code

  for _, _e in ipairs(_icmpv6_types) do
    if(_e[1] == t) then
    	return(_e[2])
    end
  end

 return(t.."/"..c)
end

-- #############################################

function getICMPTypeCode(icmp)
  local t = icmp.type
  local c = icmp.code

  for _, _e in ipairs(_icmp_types) do
    if((_e[1] == t) and (_e[2] == c)) then
    	return(_e[3])
    end
  end

 return(getICMPV6TypeCode(icmp))
end


