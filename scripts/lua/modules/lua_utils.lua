--
-- (C) 2014-15 - ntop.org
--
require "lua_trace"


function getInterfaceName(interface_id)
   local ifnames = interface.getIfNames()
   
   interface_id = tonumber(interface_id)
   for _,if_name in pairs(ifnames) do
      interface.select(if_name)
      ifstats = interface.getStats()
      if(ifstats.id == interface_id) then
	 return(ifstats.name) 
      end
   end
   
   return("")
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
  { "TCP", "tcp" },
  { "UDP", "udp" },
  { "ICMP", "icmp" },
  { "Other IP", "other ip" }
}

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

function sendHTTPHeaderIfName(mime, ifname, maxage)
  info = ntop.getInfo()

  print('HTTP/1.1 200 OK\r\n')
  print('Cache-Control: max-age=0, no-cache, no-store\r\n')
  print('Server: ntopng '..info["version"]..' ['.. info["platform"]..']\r\n')
  print('Pragma: no-cache\r\n')
  print('X-Frame-Options: DENY\r\n')
  print('X-Content-Type-Options: nosniff\r\n')
  if(_SESSION ~= nil) then print('Set-Cookie: session='.._SESSION["session"]..'; max-age=' .. maxage .. '; path=/; HttpOnly\r\n') end  
  if(ifname ~= nil) then print('Set-Cookie: ifname=' .. ifname .. '; path=/\r\n') end
  print('Content-Type: '.. mime ..'\r\n')
  print('Last-Modified: '..os.date("!%a, %m %B %Y %X %Z").."\r\n")
  print('\r\n')
end

function sendHTTPHeaderLogout(mime)
  sendHTTPHeaderIfName(mime, nil, 0)
end

function sendHTTPHeader(mime)
  sendHTTPHeaderIfName(mime, nil, 3600)
end

function printGETParameters(get)
  for key, value in pairs(get) do
    io.write(key.."="..value.."\n")
  end
end

function isEmptyString(str)
  -- io.write(str..'\n')
  if((str == nil) or (str == "")) then
    return true
  else
    return false
  end
end

function findString(str, tofind)
  local upper_lower = true
  if(str == nil) then return(nil) end
  if(tofind == nil) then return(nil) end

  str1    = string.gsub(str, "-", "_")
  tofind1 = string.gsub(tofind, "-", "_")
  rsp     = string.find(str1, tofind1, 1)

  if(upper_lower) then
    if(rsp == nil) then
      -- Lowercase
      str1 = string.lower(str1)
      tofind1 = string.lower(tofind1)
      rsp = string.find(str1, tofind1, 1)
    end

    if(rsp == nil) then
      -- Uppercase
      str1 = string.upper(str1)
      tofind1 = string.upper(tofind1)
      rsp = string.find(str1, tofind1, 1)
    end
  end
  --print(str1 .. "/" .. tofind1.."\n")
  --print(rsp)
  --print("\n")

  return(rsp)
end

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


function string.contains(String,Start)
  return(string.find(String,Start,1) ~= nil)
end

function string.starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

function printASN(asn, asname)
  if(asn > 0) then
    return("<A HREF='http://as.robtex.com/as"..asn..".html' title='"..asname.."'>"..asname.."</A> <i class='fa fa-external-link fa-lg'></i>")
  else
    return(asname)
  end
end

function shortenString(name)
   max_len = 24
    if(string.len(name) < max_len) then
      return(name)
   else
      return(string.sub(name, 1, max_len).."...")
   end
end

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


epp_rrd_names = {
  { "Positive Replies Number", "num_replies_ok.rrd" },
  { "Error Replies Number", "num_replies_error.rrd" },
  { "Query Number", "num_queries.rrd" },
  { "domain-create", "num_cmd_1.rrd" },
  { "domain-update", "num_cmd_2.rrd" },
  { "domain-delete", "num_cmd_3.rrd" },
  { "domain-restore", "num_cmd_4.rrd" },
  { "domain-transfer", "num_cmd_5.rrd" },
  { "domain-transfer-trade", "num_cmd_6.rrd" },
  { "domain-transfer-request", "num_cmd_7.rrd" },
  { "domain-transfer-trade-request", "num_cmd_8.rrd" },
  { "domain-transfer-cancel", "num_cmd_9.rrd" },
  { "domain-transfer-approve", "num_cmd_10.rrd" },
  { "domain-transfer-reject", "num_cmd_11.rrd" },
  { "contact-create", "num_cmd_12.rrd" },
  { "contact-update", "num_cmd_13.rrd" },
  { "contact-delete", "num_cmd_14.rrd" },
  { "domain-update-hosts", "num_cmd_15.rrd" },
  { "domain-update-statuses", "num_cmd_16.rrd" },
  { "domain-update-contacts", "num_cmd_17.rrd" },
  { "domain-trade", "num_cmd_18.rrd" },
  { "domain-update-simple", "num_cmd_19.rrd" },
  { "domain-info", "num_cmd_20.rrd" },
  { "contact-info", "num_cmd_21.rrd" },
  { "domain-check", "num_cmd_22.rrd" },
  { "contact-check", "num_cmd_23.rrd" },
  { "poll-req", "num_cmd_24.rrd" },
  { "domain-transfer-trade-cancel", "num_cmd_25.rrd" },
  { "domain-transfer-trade-approve", "num_cmd_26.rrd" },
  { "domain-transfer-trade-reject", "num_cmd_27.rrd" },
  { "domain-transfer-query", "num_cmd_28.rrd" },
  { "login", "num_cmd_29.rrd" },
  { "login-chg-pwd", "num_cmd_30.rrd" },
  { "logout", "num_cmd_31.rrd" },
  { "poll-ack", "num_cmd_32.rrd" },
  { "hello", "num_cmd_33.rrd" },
  { "unknown-command", "num_cmd_34.rrd" }
}

function l4Label(proto)
  return(_handleArray(l4_keys, proto))
end

function mapEppRRDName(name)
  return(_handleArray(epp_rrd_names, name))
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
  { "<i class='fa fa-sort-asc'></i> Quota Exceeded",  5 }
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

function round(num, idp)
  return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

-- Convert bytes to human readable format
function bytesToSize(bytes)
  precision = 2
  kilobyte = 1024;
  megabyte = kilobyte * 1024;
  gigabyte = megabyte * 1024;
  terabyte = gigabyte * 1024;

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

-- Convert bits to human readable format
function bitsToSize(bits)
  precision = 2
  kilobit = 1024;
  megabit = kilobit * 1024;
  gigabit = megabit * 1024;
  terabit = gigabit * 1024;

  if((bits >= kilobit) and (bits < megabit)) then
    return round(bits / kilobit, precision) .. ' Kbit/s';
  elseif((bits >= megabit) and (bits < gigabit)) then
    return round(bits / megabit, precision) .. ' Mbit/s';
  elseif((bits >= gigabit) and (bits < terabit)) then
    return round(bits / gigabit, precision) .. ' Gbit/s';
  elseif(bits >= terabit) then
    return round(bits / terabit, precision) .. ' Tbit/s';
  else
    return round(bits, precision) .. ' bps';
  end
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
  return formatValue(amount).." Pkts"
end

function capitalize(str)
  return (str:gsub("^%l", string.upper))
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

      msg = msg .. ", "
    end
    if(days > 0) then
      msg = msg .. days .. " day"
      if(days > 1) then msg = msg .. "s" end
      msg = msg .. ", "
    end
  end

  if(hours > 0) then
    msg = msg .. string.format("%d ", hours)
    if(hours > 1) then
      msg = msg .. "h"
    else
      msg = msg .. "h"
    end

    --if(hours > 1) then msg = msg .. "s" end
    msg = msg .. ", "
  end

  if(minutes > 0) then
    msg = msg .. string.format("%d min", minutes)
  end

  if(sec > 0) then
    if((string.len(msg) > 0) and (minutes > 0)) then msg = msg .. ", " end
    msg = msg .. string.format("%d sec", sec);
  end

  return msg
end

function starts(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end


-- #################################################################

function getCategoryIcon(what, cat)
   if((cat == "") or (cat == nil)) then
      return("")
   elseif(cat == "safe") then
   return("<A HREF=http://google.com/safebrowsing/diagnostic?site="..what.."&hl=en-us><font color=green><i class=\'fa fa-check\'></i></font></A>")
   elseif(cat == "malware") then
      return("<A HREF=http://google.com/safebrowsing/diagnostic?site="..what.."&hl=en-us><font color=red><i class=\'fa fa-ban\'></i></font></A>")
   else
      return(cat)
   end
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
  if(ip == "0.0.0.0") then return(true) end

  -- print(ip)
  t = string.split(ip, "%.")
  -- print(table.concat(t, "\n"))
  if(t == nil) then
    return(false) -- Might be an IPv6 address
  else
    if(tonumber(t[1]) >= 224)  then return(true) end
  end

  return(false)
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
  hosts_stats = interface.getHostsInfo()
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
     ifstats = interface.getStats()
    if(ifstats.name == interface_name) then return(ifstats.id) end
  end

  return(-1)
end

-- Windows fixes for interfaces with "uncommon chars"
function purifyInterfaceName(interface_name)
  interface_name = string.gsub(interface_name, "@", "_")
  interface_name = string.gsub(interface_name, ":", "_")
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

function flowinfo2hostname(flow_info, host_type, show_vlan)
   local name
   local orig_name

   name = flow_info[host_type..".host"]
   
   if((name == "") or (name == nil)) then
      name = flow_info[host_type..".ip"]
   end

   orig_name = name
   name = getHostAltName(name)
   
   if(name == orig_name) then
      rname = ntop.getResolvedAddress(name)
      
      if((rname ~= nil) and (rname ~= "")) then
	 name = rname
      end
   end

   -- io.write(host_type.. " / " .. flow_info[host_type..".host"].." / "..name.."\n")
  
   if(show_vlan and (flow_info["vlan"] > 0)) then
      name = name .. '@' .. flow_info["vlan"]
   end
   
   return name
end


-- Url Util --

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
    rsp = rsp..'_'..tostring(host_info["vlan"])
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

    if(major == nil or type(major) ~= "number")     then major = 0 end
    if(minor == nil or type(minor) ~= "number")     then minor = 0 end
    if(veryminor == nil or type(veryminor) ~= "number") then veryminor = 0 end

    version = tonumber(major)*1000 + tonumber(minor)*100 + tonumber(veryminor)
    return(version)
  else
    return(0)
  end
end



-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint (tbl, indent)
  if not indent then indent = 0 end

  if(tbl ~= nil) then
    for k, v in pairs(tbl) do
      formatting = string.rep("  ", indent) .. k .. ": "
      if type(v) == "table" then
        io.write(formatting)
        tprint(v, indent+1)
      elseif type(v) == 'boolean' then
        io.write(formatting .. tostring(v))
      else
        io.write(formatting .. v)
      end
    end

    io.write("\n")
  end
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


-- ############################################
-- Runtime preference

function prefsInputField(label, comment, key, value)
  if(_GET[key] ~= nil) then
    k = "ntopng.prefs."..key
    v_s = _GET[key]
    v = tonumber(v_s)
    if(v ~= nil and (v > 0) and (v < 86400)) then
      -- print(k.."="..v)
      ntop.setCache(k, tostring(v))
      value = v
    elseif (v_s ~= nil) then
      ntop.setCache(k, v_s)
      value = v_s
    end
  end

  print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  print [[
	   <td class="input-group col-lg-3" align=right><form class="navbar-form navbar-right">]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
print [[
 <div class="input-group" >
      <input type="text" class="form-control"  name="]] print(key) print [[" value="]] print(value.."") print [[">
      <span class="input-group-btn">
        <button class="btn btn-default" type="submit">Save</button>
      </span>
    </div><!-- /input-group -->
</form></td></tr>
]]

end

function toggleTableButton(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field, redis_key, disabled)
  if(_GET[submit_field] ~= nil) then
    ntop.setCache(redis_key, _GET[submit_field])
    value = _GET[submit_field]
  else
    value = ntop.getCache(redis_key)
  end
  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  -- Read it anyway to
  if(value == off_value) then
    rev_value  = on_value
    on_active  = "btn-default"
    off_active = "btn-"..off_color.." active"
  else
    rev_value  = off_value
    on_active  = "btn-"..on_color.." active"
    off_active = "btn-default"
  end

  if(label ~= "") then print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
  print('<form>\n<div class="btn-group btn-toggle">')
  print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
  print('<input type=hidden name='..submit_field..' value='..rev_value..'>\n')
  print('<button type="submit" '..disabled..' class="btn btn-sm  '..on_active..'">'..on_label..'</button>')
  print('<button '..disabled..' class="btn btn-sm '..off_active..'">'..off_label..'</button></div>\n')
  print('</form>\n')
  if(label ~= "") then print('</td></tr>') end

  return(value)
end

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


function getHumanReadableInterfaceName(interface_id)
   key = 'ntopng.prefs.'..interface_id..'.name'
   custom_name = ntop.getCache(key)
   
   if((custom_name ~= nil) and (custom_name ~= "")) then
      return(custom_name)
   else
      interface.select(interface_id)
      ifstats = interface.getStats()
      
      -- print(interface_id.."="..ifstats.name)
      
      if((interface_id ~= ifstats.description) and (ifstats.description ~= "PF_RING")) then
	 return(ifstats.description)
      else
	 return(ifstats.name)
      end
   end
end


function escapeHTML(s)
   s = string.gsub(s, "([&=+%c])", function (c)
				      return string.format("%%%02X", string.byte(c))
				   end)
   s = string.gsub(s, " ", "+")
   return s
end

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
      local ifstats = interface.getStats()
      local dirs = ntop.getDirs()
      local basedir = fixPath(dirs.workingdir .. "/" .. ifstats.id)

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
      return("<i class='fa fa-smile' alt='Fun Protocol'></i>")
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

function ternary(cond, T, F)
   if cond then return T else return F end
end

--
function split(s, delimiter)
   result = {};
   for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match);
    end
    return result;
end

function strsplit(inputstr, sep)
  if (inputstr == nil or inputstr == "") then return {} end
  if sep == nil then
    sep = "%s"
  end
  local t={} ; i=1
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

function isempty(array)
  local count = 0
  for _,__ in pairs(array) do
    count = count + 1
  end
  return (count == 0)
end

function isin(s, array)
  if (s == nil or s == "" or array == nil or isempty(array)) then return false end
  for _, v in pairs(array) do
    if (s == v) then return true end
  end
  return false
end

function maxRateToString(max_rate)
   if((max_rate == nil) or (max_rate == "")) then max_rate = -1 end
   max_rate = tonumber(max_rate)
   if(max_rate == -1) then 
      return("No Limit") 
   else
      if(max_rate == 0) then 
	 return("Drop All Traffic") 
      else
	 if(max_rate < 1024) then
	    return(max_rate.." Kbps")
	 else
	    local mr
	    mr = round(max_rate / 1024, 2)
	    return(mr.." Mbps")
	 end
      end
   end
end