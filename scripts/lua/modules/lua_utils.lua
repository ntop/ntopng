--
-- (C) 2014-20 - ntop.org
--

dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/i18n/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/flow_dbms/?.lua;" .. package.path

require "lua_trace"
require "ntop_utils"
locales_utils = require "locales_utils"
local os_utils = require "os_utils"
local format_utils = require "format_utils"
local page_utils = require("page_utils")

-- ##############################################
-- TODO: replace those globals with locals everywhere

secondsToTime   = format_utils.secondsToTime
msToTime        = format_utils.msToTime
bytesToSize     = format_utils.bytesToSize
formatPackets   = format_utils.formatPackets
formatFlows     = format_utils.formatFlows
formatValue     = format_utils.formatValue
pktsToSize      = format_utils.pktsToSize
bitsToSize      = format_utils.bitsToSize
round           = format_utils.round
bitsToSizeMultiplier = format_utils.bitsToSizeMultiplier

-- ##############################################

-- Note: Regexs are applied by default. Pass plain=true to disable them.
function string.contains(String,Start,plain)
   if type(String) ~= 'string' or type(Start) ~= 'string' then
      return false
   end

   local i,j = string.find(String, Start, 1, plain)

   return(i ~= nil)
end

-- ##############################################

function shortenString(name, max_len)
   if(name == nil) then return("") end

   if max_len == nil then
      max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
      max_len = tonumber(max_len)
      if(max_len == nil) then max_len = 24 end
   end

   if(string.len(name) < max_len) then
      return(name)
   else
      return(string.sub(name, 1, max_len).."...")
   end
end

-- ##############################################

function getInterfaceName(interface_id, windows_skip_description)
   if(interface_id == getSystemInterfaceId()) then
      return(getSystemInterfaceName())
   end

   local ifnames = interface.getIfNames()
   local iface = ifnames[tostring(interface_id)]

   if iface ~= nil then
      if(windows_skip_description ~= true and string.contains(iface, "{")) then -- Windows
         local old_iface = interface.getId()

         -- Use the interface description instead of the name
         interface.select(tostring(iface))
         iface = interface.getStats().description

         interface.select(tostring(old_iface))
      end

      return(iface)
   end

   return("")
end

-- ##############################################

function getInterfaceId(interface_name)
   if(interface_name == getSystemInterfaceName()) then
      return(getSystemInterfaceId())
   end

   local ifnames = interface.getIfNames()

   for if_id, if_name in pairs(ifnames) do
      if if_name == interface_name then
         return tonumber(if_id)
      end
   end

   return(-1)
end

-- ##############################################

function getFirstInterfaceId()
   local ifid = interface.getFirstInterfaceId()

   if ifid ~= nil then
      return ifid, getInterfaceName(ifid)
   end

   return -1, ""
end

-- ##############################################

function isAllowedSystemInterface()
   return ntop.isAllowedInterface(tonumber(getSystemInterfaceId()))
end

-- ##############################################

-- Note that ifname can be set by Lua.cpp so don't touch it if already defined
if((ifname == nil) and (_GET ~= nil)) then
   ifname = _GET["ifid"]

   if(ifname ~= nil) then
      if(ifname.."" == tostring(tonumber(ifname)).."") then
	 -- ifname does not contain the interface name but rather the interface id
	 ifname = getInterfaceName(ifname, true)
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

l4_keys = {
  { "TCP",    "tcp",     6 },
  { "UDP",    "udp",    17 },
  { "ICMP",   "icmp",    1 },
  { "ICMPv6", "icmpv6", 58 },
  { "IGMP",   "igmp",    2 },
  { "Other IP", "other_ip", -1 }
}

L4_PROTO_KEYS = {tcp=6, udp=17, icmp=1, other_ip=-1}

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

-- ##############################################

function sendHTTPHeaderIfName(mime, ifname, maxage, content_disposition, extra_headers)
  info = ntop.getInfo(false)
  local cookie_attr = ntop.getCookieAttributes()
  local lines = {
    'Cache-Control: max-age=0, no-cache, no-store',
    'Server: ntopng '..info["version"]..' ['.. info["platform"]..']',
    'Pragma: no-cache',
    'X-Frame-Options: DENY',
    'X-Content-Type-Options: nosniff',
    'Content-Type: '.. mime,
    'Last-Modified: '..os.date("!%a, %m %B %Y %X %Z"),
  }

  if(_SESSION ~= nil) then
    lines[#lines + 1] = 'Set-Cookie: session='.._SESSION["session"]..'; max-age=' .. maxage .. '; path=/; ' .. cookie_attr
  end

  if(ifname ~= nil) then
    lines[#lines + 1] = 'Set-Cookie: ifname=' .. ifname .. '; path=/' .. cookie_attr
  end

  if(content_disposition ~= nil) then
    lines[#lines + 1] = 'Content-Disposition: '..content_disposition
  end

  if type(extra_headers) == "table" then
     for hname, hval in pairs(extra_headers) do
        lines[#lines + 1] = hname..': '..hval
     end
  end

  -- Buffer the HTTP reply and write it in one "print" to avoid fragmenting
  -- it into multiple packets, to ease HTTP debugging with wireshark.
  print("HTTP/1.1 200 OK\r\n" .. table.concat(lines, "\r\n") .. "\r\n\r\n")
end

-- ##############################################

function sendHTTPHeaderLogout(mime, content_disposition)
  sendHTTPHeaderIfName(mime, nil, 0, content_disposition)
end

-- ##############################################

function sendHTTPHeader(mime, content_disposition, extra_headers)
  sendHTTPHeaderIfName(mime, nil, 3600, content_disposition, extra_headers)
end

-- ##############################################

function sendHTTPContentTypeHeader(content_type, content_disposition, charset)
  local charset = charset or "utf-8"
  local mime = content_type.."; charset="..charset
  sendHTTPHeader(mime, content_disposition)
end

-- ##############################################

function printGETParameters(get)
  for key, value in pairs(get) do
    io.write(key.."="..value.."\n")
  end
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

function printASN(asn, asname)
  asname = asname:gsub('"','')
  if(asn > 0) then
    return("<A HREF='http://as.robtex.com/as"..asn..".html' title='"..asname.."'>"..asname.."</A> <i class='fas fa-external-link-alt fa-lg'></i>")
  else
    return(asname)
  end
end

-- ##############################################

function urlencode(str)
   str = string.gsub (str, "\r?\n", "\r\n")
   str = string.gsub (str, "([^%w%-%.%_%~ ])",
		      function (c) return string.format ("%%%02X", string.byte(c)) end)
   str = string.gsub (str, " ", "+")
   return str
end

-- ##############################################

function getPageUrl(base_url, params)
   if table.empty(params) then
      return base_url
   end

   local encoded = {}

   for k, v in pairs(params) do
      encoded[k] = urlencode(v)
   end

   local delim = "&"
   if not string.find(base_url, "?") then
     delim = "?"
   end

   return base_url .. delim .. table.tconcat(encoded, "=", "&")
end

-- ##############################################

function printIpVersionDropdown(base_url, page_params)
   local ipversion = _GET["version"]
   local ipversion_filter
   if not isEmptyString(ipversion) then
      ipversion_filter = '<span class="fas fa-filter"></span>'
   else
      ipversion_filter = ''
   end
   local ipversion_params = table.clone(page_params)
   ipversion_params["version"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.ip_version")) print[[]] print(ipversion_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, ipversion_params)) print[[">]] print(i18n("flows_page.all_ip_versions")) print[[</a></li>\
         <li]] if ipversion == "4" then print(' class="active"') end print[[><a class="dropdown-item" href="]] ipversion_params["version"] = "4"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv4_only")) print[[</a></li>\
         <li]] if ipversion == "6" then print(' class="active"') end print[[><a class="dropdown-item" href="]] ipversion_params["version"] = "6"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv6_only")) print[[</a></li>\
      </ul>]]
end

-- ##############################################

function printVLANFilterDropdown(base_url, page_params)
   local vlans = interface.getVLANsList()

   if vlans == nil then vlans = {VLANs={}} end
   vlans = vlans["VLANs"]

   local ids = {}
   for _, vlan in ipairs(vlans) do
      ids[#ids + 1] = vlan["vlan_id"]
   end

   local vlan_id = _GET["vlan"]
   local vlan_id_filter = ''
   if not isEmptyString(vlan_id) then
      vlan_id_filter = '<span class="fas fa-filter"></span>'
   end

   local vlan_id_params = table.clone(page_params)
   vlan_id_params["vlan"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.vlan")) print[[]] print(vlan_id_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">]] print(i18n("flows_page.all_vlan_ids")) print[[</a></li>\]]
   for _, vid in ipairs(ids) do
      vlan_id_params["vlan"] = vid
      print[[
         <li>\
           <a class="dropdown-item" href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">VLAN ]] print(tostring(vid)) print[[</a></li>\]]
   end
   print[[

      </ul>]]
end

-- ##############################################

function printTrafficTypeFilterDropdown(base_url, page_params)
   local traffic_type = _GET["traffic_type"]
   local traffic_type_filter = ''
   if not isEmptyString(traffic_type) then
      traffic_type_filter = '<span class="fas fa-filter"></span>'
   end

   local traffic_type_params = table.clone(page_params)
   traffic_type_params["traffic_type"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.direction")) print[[]] print(traffic_type_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_all")) print[[</a></li>\]]

   -- now forthe one-way
   traffic_type_params["traffic_type"] = "one_way"
   print[[
         <li]] if traffic_type == "one_way" then print(' class="active"') end print[[>\
           <a class="dropdown-item" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_one_way")) print[[</a></li>\]]
   traffic_type_params["traffic_type"] = "bidirectional"
   print[[
         <li]] if traffic_type == "bidirectional" then print(' class="active"') end print[[>\
           <a class="dropdown-item" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_two_ways")) print[[</a></li>\]]
   print[[
      </ul>]]
end


-- ##############################################

function printFlowDevicesFilterDropdown(base_url, page_params)
   if (ntop.isPro()) then
      package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
      require "snmp_utils"
   end

   local flowdevs = interface.getFlowDevices()
   local vlans = interface.getVLANsList()

   if flowdevs == nil then flowdevs = {} end

   local devips = {}
   for dip, _ in pairsByValues(flowdevs, asc) do
      devips[#devips + 1] = dip
   end

   local cur_dev = _GET["deviceIP"]
   local cur_dev_filter = ''
   local snmp_community = ''
   if not isEmptyString(cur_dev) then
      cur_dev_filter = '<span class="fas fa-filter"></span>'
   end

   local dev_params = table.clone(page_params)
   for _, p in pairs({"deviceIP", "outIfIdx", "inIfIdx"}) do
      dev_params[p] = nil
   end

   print[[, '<div class="btn-group float-right">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.device_ip")) print[[]] print(cur_dev_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, dev_params)) print[[">]] print(i18n("flows_page.all_devices")) print[[</a></li>\]]
   for _, dip in ipairs(devips) do
      dev_params["deviceIP"] = dip
      local snmp_community = get_snmp_community(dip, true --[[ no default --]])
      if not isEmptyString(snmp_community) then
	 local snmp_name = get_snmp_device_name(dip, snmp_community)
	 if not isEmptyString(snmp_name) and snmp_name ~= dip then
	    dip = dip .. "["..shortenString(snmp_name).."]"
	 end
      else
	 local resname = getResolvedAddress(hostkey2hostinfo(dip))
	 if not isEmptyString(resname) and resname ~= dip then
	    dip = dip .. "["..shortenString(resname).."]"
	 end
      end

      print[[
         <li>\
           <a class="dropdown-item" href="]] print(getPageUrl(base_url, dev_params)) print[[">]] print(i18n("flows_page.device_ip").." "..dip) print[[</a></li>\]]
   end
   print[[
      </ul>\
</div>']]

   if cur_dev ~= nil then -- also print dropddowns for input and output interface index
      local ports = interface.getFlowDeviceInfo(cur_dev)

      for _, direction in pairs({"outIfIdx", "inIfIdx"}) do
	 local cur_if = _GET[direction]
	 local cur_if_filter = ''
	 if not isEmptyString(cur_if) then
	    cur_if_filter = '<span class="fas fa-filter"></span>'
	 end

	 local if_params = table.clone(page_params)

	 if_params[direction] = nil
	    print[[, '<div class="btn-group float-right">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page."..direction)) print[[]] print(cur_if_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, if_params)) print[[">]] print(i18n("flows_page.all_"..direction)) print[[</a></li>\]]

	    for portidx, _ in pairsByKeys(ports, asc) do
	       if_params[direction] = portidx
	       print[[
         <li>\
           <a class="dropdown-item" href="]] print(getPageUrl(base_url, if_params)) print[[">]] print(i18n("flows_page."..direction).." "..tostring(portidx)) print[[</a></li>\]]
	    end
	    print[[
      </ul>\
</div>']]
      end

   end
end

-- ##############################################

--
-- Returns indexes to be used for string shortening. The portion of to_shorten between
-- middle_start and middle_end will be inside the bounds.
--
--    to_shorten: string to be shorten
--    middle_start: middle part begin index
--    middle_end: middle part begin index
--    maxlen: maximum length
--
function shortenInTheMiddle(to_shorten, middle_start, middle_end, maxlen)
  local maxlen = maxlen - (middle_end - middle_start)

  if maxlen <= 0 then
    return 0, string.len(to_shorten)
  end

  local left_slice = math.max(middle_start - math.floor(maxlen / 2), 1)
  maxlen = maxlen - (middle_start - left_slice - 1)
  local right_slice = math.min(middle_end + maxlen, string.len(to_shorten))

  return left_slice, right_slice
end

-- ##############################################

function shortHostName(name)
  local chunks = {name:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
  if(#chunks == 4) then
    return(name)
  else
    local max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
    max_len = tonumber(max_len)
    if(max_len == nil) then max_len = 24 end

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

function l4_proto_to_id(proto_name)
  for _, proto in pairs(l4_keys) do
    if proto[2] == proto_name then
      return(proto[3])
    end
  end
end

function l4_proto_to_string(proto_id)
   proto_id = tonumber(proto_id)

   for _, proto in pairs(l4_keys) do
      if proto[3] == proto_id then
         return proto[1], proto[2]
      end
   end

   return string.format("%d", proto_id)
end

-- ##############################################

function noHtml(s)
   if s == nil then return nil end

   local gsub, char = string.gsub, string.char
   local entityMap  = {lt = "<", gt = ">" , amp = "&", quot ='"', apos = "'"}
   local entitySwap = function(orig, n, s)
      return (n == '' and entityMap[s])
	 or (n == "#" and tonumber(s)) and string.char(s)
	 or (n == "#x" and tonumber(s,16)) and string.char(tonumber(s,16))
	 or orig
   end

   local function unescape(str)
      return (gsub( str, '(&(#?x?)([%d%a]+);)', entitySwap ))
   end

   local cleaned = s:gsub("<[aA].->(.-)</[aA]>","%1")
      :gsub("%s*<[iI].->(.-)</[iI]>","%1")
      :gsub("<.->(.-)</.->","%1") -- note: this does not handle nested tags
      :gsub("^%s*(.-)%s*$", "%1")

   return unescape(cleaned)
end

function areAlertsEnabled()
  return (ntop.getPref("ntopng.prefs.disable_alerts_generation") ~= "1")
end

function isScoreEnabled()
  return(ntop.isEnterprise() and (ntop.getPref("ntopng.prefs.enable_score") == "1"))
end

function mustScanAlerts(ifstats)
   return areAlertsEnabled()
end

function hasAlertsDisabled()
  _POST = _POST or {}
  return ((_POST["disable_alerts_generation"] ~= nil) and (_POST["disable_alerts_generation"] == "1")) or
      ((_POST["disable_alerts_generation"] == nil) and (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1"))
end

function hasNagiosSupport()
  if prefs == nil then
    prefs = ntop.getPrefs()
  end
  return prefs.nagios_nsca_host ~= nil
end

function hasNindexSupport()
   if not ntop.isEnterprise() or ntop.isWindows() then
      return false
   end

   -- TODO optimize
   if prefs == nil then
    prefs = ntop.getPrefs()
   end

   if prefs.is_nindex_enabled then
      return true
   end

   return false
end

-- NOTE: global nindex support may be enabled but some disable on some interfaces
function interfaceHasNindexSupport()
  return(hasNindexSupport() and interface.nIndexEnabled())
end

--for _key, _value in pairsByKeys(vals, rev) do
--   print(_key .. "=" .. _value .. "\n")
--end

function truncate(x)
   return x<0 and math.ceil(x) or math.floor(x)
end

-- Note that the function below returns a string as returning a number
-- would not help as a new float would be returned
function toint(num)
   return string.format("%u", truncate(num))
end

function capitalize(str)
  return (str:gsub("^%l", string.upper))
end

local function starstring(len)
local s = ""

  while(len > 0) do
   s = s .."*"
   len = len -1
  end

  return(s)
end

function obfuscate(str)
  local len = string.len(str)
  local in_clear = 2

  if(len <= in_clear) then
    return(starstring(len))
  else
    return(string.sub(str, 0, in_clear)..starstring(len-in_clear))
  end
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

function formatEpoch(epoch)
   return(format_utils.formatEpoch(epoch))
end

function starts(String,Start)
   if((String == nil) or (Start == nil)) then
      return(false)
   end

  return string.sub(String,1,string.len(Start))==Start
end

function ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

-- #################################################################

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

function isIPv4(address)
  local chunks = {address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}

  if #chunks == 4 then
    for _, v in pairs(chunks) do
      if (tonumber(v) < 0) or (tonumber(v) > 255) then
        return false
      end
    end

    return true
  end

  return false
end

function isIPv4Network(address)
   local parts = split(address, "/")

   if #parts == 2 then
      local prefix = tonumber(parts[2])

      if (prefix == nil) or (math.floor(prefix) ~= prefix) or (prefix < 0) or (prefix > 32) then
         return false
      end
   elseif #parts ~= 1 then
      return false
   end

   return isIPv4(parts[1])
end

function addGoogleMapsScript()
   local g_maps_key = ntop.getCache('ntopng.prefs.google_apis_browser_key')
   if g_maps_key ~= nil and g_maps_key~= "" then
      g_maps_key = "&key="..g_maps_key
   else
   g_maps_key = ""
   end
   print("<script src=\"https://maps.googleapis.com/maps/api/js?v=3.exp"..g_maps_key.."\"></script>\n")
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
  print [[
  <div class="progress">
       <div id="]] print(name) print [[" class="progress-bar bg-warning"></div>
  </div>
  ]]
  if(url ~= nil) then print('</A>\n') end
end

-- Compute the difference in seconds between local time and UTC.
function get_timezone()
  local now = os.time()
  return math.floor(os.difftime(now, os.time(os.date("!*t", now))))
end

function getCategoriesWithProtocols()
   local protocol_categories = interface.getnDPICategories()

   for k,v in pairsByKeys(protocol_categories) do
      protocol_categories[k] = {id=v, protos=interface.getnDPIProtocols(tonumber(v)), count=0}

      for proto,_ in pairs(protocol_categories[k].protos) do
         protocol_categories[k].count = protocol_categories[k].count + 1
      end
   end

   return protocol_categories
end

function isValidPoolMember(member)
  if isEmptyString(member) then
    return false
  end

  if isMacAddress(member) then
    return true
  end

  -- vlan is mandatory here
  local vlan_idx = string.find(member, "@")
  if ((vlan_idx == nil) or (vlan_idx == 1)) then
    return false
  end
  local other = string.sub(member, 1, vlan_idx-1)
  local vlan = tonumber(string.sub(member, vlan_idx+1))
  if (vlan == nil) or (vlan < 0) then
    return false
  end

  -- prefix is mandatory here
  local address, prefix = splitNetworkPrefix(other)
  if prefix == nil then
    return false
  end
  if isIPv4(address) and (tonumber(prefix) >= 0) and (tonumber(prefix) <= 32) then
    return true
  elseif isIPv6(address) and (tonumber(prefix) >= 0) and (tonumber(prefix) <= 128) then
    return true
  end

  return false
end

function host2member(ip, vlan, prefix)
  if prefix == nil then
    if isIPv4(ip) then
      prefix = 32
    else
      prefix = 128
    end
  end

  return ip .. "/" .. tostring(prefix) .. "@" .. tostring(vlan)
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
  hosts_stats = hosts_stats["hosts"]
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

-- Windows fixes for interfaces with "uncommon chars"
function purifyInterfaceName(interface_name)
  -- io.write(debug.traceback().."\n")
  interface_name = string.gsub(interface_name, "@", "_")
  interface_name = string.gsub(interface_name, ":", "_")
  interface_name = string.gsub(interface_name, "/", "_")
  return(interface_name)
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

-- #################################

-- Aggregates items below some edge
-- edge: minimum percentage value to create collision
-- min_col: minimum collision groups to aggregate
function aggregatePie(values, values_sum, edge, min_col)
   local edge = edge or 0.09
   min_col = min_col or 2
   local aggr = {}
   local other = i18n("other")
   local below_edge = {}

   -- Initial lookup
   for k,v in pairs(values) do
      if v / values_sum <= edge then
         -- too small
         below_edge[#below_edge + 1] = k
      else
         aggr[k] = v
      end
   end

   -- Decide if to aggregate
   for _,k in pairs(below_edge) do
      if #below_edge >= min_col then
         -- aggregate
         aggr[other] = aggr[other] or 0
         aggr[other] = aggr[other] + values[k]
      else
         -- do not aggregate
         aggr[k] = values[k]
      end
   end

   return aggr
end

-- #################################

function hostVisualization(ip, name, vlan)
   if (ip ~= name) then
      if isIPv6(ip) then
        name = name.." [IPv6]"
      end
   else
      if vlan ~= nil and tonumber(vlan) > 0 then
        name = name.."@"..vlan
      end
   end

   return name
end

-- #################################

-- NOTE: prefer the getResolvedAddress on this function
function resolveAddress(hostinfo, allow_empty)
   local hostname = ntop.resolveName(hostinfo["host"])
   if isEmptyString(hostname) then
      -- Not resolved
      if allow_empty == true then
         return hostname
      else
         -- this function will take care of formatting the IP
         return getResolvedAddress(hostinfo)
      end
   end
   return hostVisualization(hostinfo["host"], hostname, hostinfo["vlan"])
end

-- #################################

-- NOTE: use host2name when possible
function getResolvedAddress(hostinfo)
   local hostname = ntop.getResolvedName(hostinfo["host"])
   return hostVisualization(hostinfo["host"], hostname, hostinfo["vlan"])
end

-- #################################

function getIpUrl(ip)
   if isIPv6(ip) then
      -- https://www.ietf.org/rfc/rfc2732.txt
      return "["..ip.."]"
   end
   return ip
end

-- #################################

function getApplicationIcon(name)
  local icon = ""
  if(name == nil) then name = "" end

  if(findString(name, "Skype")) then icon = '<i class=\'fas fa-skype\'></i>'
  elseif(findString(name, "Unknown")) then icon = '<i class=\'fas fa-question\'></i>'
  elseif(findString(name, "Twitter")) then icon = '<i class=\'fab fa-twitter\'></i>'
  elseif(findString(name, "DropBox")) then icon = '<i class=\'fab fa-dropbox\'></i>'
  elseif(findString(name, "Spotify")) then icon = '<i class=\'fab fa-spotify\'></i>'
  elseif(findString(name, "Apple")) then icon = '<i class=\'fab fa-apple\'></i>'
  elseif(findString(name, "Google") or
    findString(name, "Chrome")) then icon = '<i class=\'fab fa-google-plus-g\'></i>'
  elseif(findString(name, "FaceBook")) then icon = '<i class=\'fab fa-facebook\'></i>'
  elseif(findString(name, "Youtube")) then icon = '<i class=\'fab fa-youtube\'></i>'
  elseif(findString(name, "thunderbird")) then icon = '<i class=\'fas fa-paper-plane\'></i>'
  end

  return(icon)
end

-- #################################

function getApplicationLabel(name)
  local icon = getApplicationIcon(name)

  name = name:gsub("^%l", string.upper)
  return(icon.." "..name)
end

-- #################################

function getCategoryLabel(cat_name)
  cat_name = cat_name:gsub("^%l", string.upper)
  return(cat_name)
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

function splitNetworkPrefix(net)
   local prefix = tonumber(net:match("/(.+)"))
   local address = net:gsub("/.+","")
   return address, prefix
end

-- ##############################################

function splitNetworkWithVLANPrefix(net_mask_vlan)
   local vlan = tonumber(net_mask_vlan:match("@(.+)"))
   local net_mask = net_mask_vlan:gsub("@.+","")
   local prefix = tonumber(net_mask:match("/(.+)"))
   local address = net_mask:gsub("/.+","")
   return address, prefix, vlan
end

-- ##############################################

function splitProtocol(proto_string)
  local parts = string.split(proto_string, "%.")
  local app_proto
  local master_proto

  if parts == nil then
    master_proto = proto_string
    app_proto = nil
  else
    master_proto = parts[1]
    app_proto = parts[2]
  end

  return master_proto, app_proto
end

-- ##############################################

function getHostAltNamesKey()
   return "ntopng.host_labels"
end

-- ##############################################

function getDhcpNamesKey(ifid)
   return "ntopng.dhcp."..ifid..".cache"
end

-- ##############################################

-- Used to avoid resolving host names too many times
resolved_host_labels_cache = {}

-- host_ip can be a mac. host_mac can be null.
function getHostAltName(host_ip, host_mac)
   local alt_name = nil

   if not isEmptyString(host_ip) then
      alt_name = resolved_host_labels_cache[host_ip]
   end

   -- cache hit
   if(alt_name ~= nil) then
      return(alt_name)
   end

   alt_name = ntop.getHashCache(getHostAltNamesKey(), host_ip)

   if (isEmptyString(alt_name) and (host_mac ~= nil)) then
      alt_name = ntop.getHashCache(getHostAltNamesKey(), host_mac)
   end

   if isEmptyString(alt_name) and ifname ~= nil then
      local key = getDhcpNamesKey(getInterfaceId(ifname))

      if host_mac ~= nil then
         alt_name = ntop.getHashCache(key, host_mac)
      elseif isMacAddress(host_ip) then
         alt_name = ntop.getHashCache(key, host_ip)
      end
   end

   if isEmptyString(alt_name) then
     alt_name = host_ip
   end

   if not isEmptyString(alt_name) then
      resolved_host_labels_cache[host_ip] = alt_name
   end

   return(alt_name)
end

function setHostAltName(host_ip, alt_name)
   ntop.setHashCache(getHostAltNamesKey(), host_ip, alt_name)
end

-- Mac Addresses --

-- A function to give a useful device name
function getDeviceName(device_mac, skip_manufacturer)
   local name = getHostAltName(device_mac)

   if name == device_mac then
      -- Not found, try with first host
      local info = interface.getHostsInfo(false, nil, 1, 0, nil, nil, nil, tonumber(vlan), nil,
               nil, device_mac)

      if (info ~= nil) then
         for x, host in pairs(info.hosts) do
            if not isEmptyString(host.name) and host.name ~= host.ip and host.name ~= "NoIP" then
               name = host.name
            elseif host.ip ~= "0.0.0.0" then
               name = getHostAltName(host.ip)

               if name == host.ip then
                  name = nil
               end
            end
            break
         end
      else
         name = nil
      end
   end

   if isEmptyString(name) then
      if (not skip_manufacturer) then
         name = get_symbolic_mac(device_mac, true)
      else
         -- last resort
         name = device_mac
      end
   end

   return name
end

local specialMACs = {
  "01:00:0C",
  "01:80:C2",
  "01:00:5E",
  "01:0C:CD",
  "01:1B:19",
  "FF:FF",
  "33:33"
}
function isSpecialMac(mac)
  for _,key in pairs(specialMACs) do
     if(string.contains(mac, key)) then
        return true
     end
  end

  return false
end

-- Flow Utils --

function host2name(name, vlan)
   local orig_name = name

   vlan = tonumber(vlan or "0")

   name = getHostAltName(name)

   if(name == orig_name) then
      local rname = getResolvedAddress({host=name, vlan=vlan})

      if((rname ~= nil) and (rname ~= "")) then
	 name = rname
      end
   elseif(vlan > 0) then
      name = name .. '@' .. vlan
   end

   return name
end

function flowinfo2hostname(flow_info, host_type, alerts_view)
   local name
   local orig_name

   if alerts_view and not hasNindexSupport() then
      -- do not return resolved name as it will hide the IP address
      return(flow_info[host_type..".ip"])
   end

   if(host_type == "srv") then
      if flow_info["host_server_name"] ~= nil and flow_info["host_server_name"] ~= "" and flow_info["host_server_name"]:match("%w") then
	 -- remove possible ports from the name
	 return(flow_info["host_server_name"]:gsub(":%d+$", ""))
      end
      if(flow_info["protos.tls.certificate"] ~= nil and flow_info["protos.tls.certificate"] ~= "") then
	 return(flow_info["protos.tls.certificate"])
      end
   end

   name = flow_info[host_type..".host"]

   if((name == "") or (name == nil)) then
      name = flow_info[host_type..".ip"]
   end

   return(host2name(name, flow_info["vlan"]))
end

function flowinfo2process(process, host_info_to_url)
   local fmt, proc_name, proc_user_name = '', '', ''

   if process then
      -- TODO: add links back once restored

      if not isEmptyString(process["name"]) then
	 local full_clean_name = process["name"]:gsub("'",'')
	 local t = split(full_clean_name, "/")
	 
	 clean_name = t[#t]

	 proc_name = string.format("<A HREF='%s/lua/process_details.lua?%s&pid_name=%s&pid=%u'><i class='fas fa-terminal'></i> %s</A>",
				   ntop.getHttpPrefix(),
				   host_info_to_url,
				   full_clean_name,
				   process["pid"],
				   clean_name)
      end

      -- if not isEmptyString(process["user_name"]) then
      -- 	 local clean_user_name = process["user_name"]:gsub("'", '')

      -- 	 proc_user_name = string.format("<A HREF='%s/lua/username_details.lua?%s&username=%s&uid=%u'><i class='fas fa-linux'></i> %s</A>",
      -- 					ntop.getHttpPrefix(),
      -- 					host_info_to_url,
      -- 					clean_user_name,
      -- 					process["uid"],
      -- 					clean_user_name)
      -- end

      fmt = string.format("[%s]", table.concat({proc_user_name, proc_name}, ' '))
   end

   return fmt
end

-- ##############################################

function flowinfo2container(container)
   local fmt, cont_name, pod_name = '', '', ''

   if container then
      cont_name = string.format("<A HREF='%s/lua/flows_stats.lua?container=%s'><i class='fas fa-ship'></i> %s</A>",
				ntop.getHttpPrefix(),
				container["id"], format_utils.formatContainer(container))

      -- local formatted_pod = format_utils.formatPod(container)
      -- if not isEmptyString(formatted_pod) then
      -- 	 pod_name = string.format("<A HREF='%s/lua/containers_stats.lua?pod=%s'><i class='fas fa-crosshairs'></i> %s</A>",
      -- 				  ntop.getHttpPrefix(),
      -- 				  formatted_pod,
      -- 				  formatted_pod)
      -- end

      fmt = string.format("[%s]", table.concat({cont_name, pod_name}, ''))   
   end

   return fmt
end

-- ##############################################

function getLocalNetworkAliasKey()
   return "ntopng.network_aliases"
end

-- ##############################################

function getLocalNetworkAlias(network)
   local alias = ntop.getHashCache(getLocalNetworkAliasKey(), network)

   if not isEmptyString(alias) then
      return alias
   end

   return network
end

-- ##############################################

function getFullLocalNetworkName(network)
   local alias = getLocalNetworkAlias(network)

   if alias ~= network then
      return string.format("%s [%s]", alias, network)
   end

   return network
end

-- ##############################################

function setLocalNetworkAlias(network, alias)
   if((network ~= alias) or isEmptyString(alias)) then
      ntop.setHashCache(getLocalNetworkAliasKey(), network, alias)
   else
      ntop.delHashCache(getLocalNetworkAliasKey(), network)
   end
end

-- ##############################################

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

  if((host_info["vlan"] ~= nil and host_info["vlan"] ~= 0) or show_vlan)  then
    rsp = rsp..'@'..tostring(host_info["vlan"] or 0)
  end

  if(debug_host) then traceError(TRACE_DEBUG,TRACE_CONSOLE,"HOST2URL => ".. rsp .. "\n") end
  return rsp
end

function member2visual(member)
   local info = hostkey2hostinfo(member)
   local host = info.host
   local hlen = string.len(host)

   if string.ends(host, "/32") and isIPv4(string.sub(host, 1, hlen-3)) then
    host = string.sub(host, 1, hlen-3)
  elseif string.ends(host, "/128") and isIPv6(string.sub(host, 1, hlen-4)) then
    host = string.sub(host, 1, hlen-4)
  end

  return hostinfo2hostkey({host=host, vlan=info.vlan})
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

function hostinfo2url(host_info, host_type, novlan)
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
    elseif(host_info["mac"] ~= nil) then
      rsp = rsp..'host='..host_info["mac"]
    --Note: the host'name' is not supported (not accepted by lint)
    --elseif(host_info["name"] ~= nil) then
    --  rsp = rsp..'host='..host_info["name"]
    end
  end

  if(novlan == nil) then
    if((host_info["vlan"] ~= nil) and (tonumber(host_info["vlan"]) ~= 0)) then
      if(version == 0) then
        rsp = rsp..'&vlan='..tostring(host_info["vlan"])
      elseif(version == 1) then
        rsp = rsp..'@'..tostring(host_info["vlan"])
      end
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

-- NOTE: on index based tables using #table is much more performant
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

function getRedisIfacePrefix(ifid)
   return "ntopng.prefs.ifid_"..tostring(ifid)
end

-----  End of Redis Utils  ------


function isPausedInterface(current_ifname)
   if(not isEmptyString(_POST["toggle_local"])) then
      return(_POST["toggle_local"] == "0")
   end

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
   local table_key = getRedisPrefix("ntopng.sort.table")
   local value = nil

  if(table_type ~= nil) then
     value = ntop.getHashCache(table_key, "sort_"..table_type)
  end
  if((value == nil) or (value == "")) then value = 'column_' end
  return(value)
end

function getDefaultTableSortOrder(table_type, force_get)
   local table_key = getRedisPrefix("ntopng.sort.table")
   local value = nil

  if(table_type ~= nil) then
    value = ntop.getHashCache(table_key, "sort_order_"..table_type)
  end
  if((value == nil) or (value == "")) and (force_get ~= true) then value = 'desc' end
  return(value)
end

function getDefaultTableSize()
  table_key = getRedisPrefix("ntopng.sort.table")
  value = ntop.getHashCache(table_key, "rows_number")
  if((value == nil) or (value == "")) then value = 10 end
  return(tonumber(value))
end

function tablePreferences(key, value, force_set)
  table_key = getRedisPrefix("ntopng.sort.table")

  if((value == nil) or (value == "")) and (force_set ~= true) then
    -- Get preferences
    return ntop.getHashCache(table_key, key)
  else
    -- Set preferences
    ntop.setHashCache(table_key, key, value)
    return(value)
  end
end

function getInterfaceSpeed(ifid)
   local ifname = getInterfaceName(ifid)
   local ifspeed = ntop.getCache('ntopng.prefs.'..ifname..'.speed')
   if not isEmptyString(ifspeed) and tonumber(ifspeed) ~= nil then
      ifspeed = tonumber(ifspeed)
   else
      ifspeed = interface.getMaxIfSpeed(ifid)
   end

   return ifspeed
end

function getInterfaceRefreshRate(ifid)
   local key = getRedisIfacePrefix(ifid)..".refresh_rate"
   local refreshrate = ntop.getCache(key)

   if isEmptyString(refreshrate) or tonumber(refreshrate) == nil then
      refreshrate = 3
   else
      refreshrate = tonumber(refreshrate)
   end

   return refreshrate
end

function setInterfaceRegreshRate(ifid, refreshrate)
   local key = getRedisIfacePrefix(ifid)..".refresh_rate"

   if isEmptyString(refreshrate) then
      ntop.delCache(key)
   else
      ntop.setCache(key, tostring(refreshrate))
   end
end

local function getCustomnDPIProtoCategoriesKey()
   return "ntop.prefs.custom_nDPI_proto_categories"
end

function getCustomnDPIProtoCategories()
   local ndpi_protos = interface.getnDPIProtocols()
   local key = getCustomnDPIProtoCategoriesKey()

   local res = {}
   for _, app_id in pairs(ndpi_protos) do
      local custom_category = ntop.getHashCache(key, tostring(app_id))
      if not isEmptyString(custom_category) then
	 res[tonumber(app_id)] = tonumber(custom_category)
      end
   end

   return res
end

function setCustomnDPIProtoCategory(app_id, new_cat_id)
   ntop.setnDPIProtoCategory(app_id, new_cat_id)

   local key = getCustomnDPIProtoCategoriesKey(ifid)

   -- NOTE: when the ndpi struct changes, the custom associations are
   -- reloaded by Ntop::loadProtocolsAssociations
   ntop.setHashCache(key, tostring(app_id), tostring(new_cat_id));
end

-- "Some Very Long String" -> "Some Ver...g String"
function shortenCollapse(s, max_len)
   local replacement = "..."
   local r_len = string.len(replacement)
   local s_len = string.len(s)

   if max_len == nil then
      max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
      max_len = tonumber(max_len)
      if(max_len == nil) then max_len = 24 end
   end

   if max_len <= r_len then
      return replacement
   end

   if s_len > max_len then
      local half = math.floor((max_len-r_len) / 2)
      return string.sub(s, 1, half) .. replacement .. string.sub(s, s_len-half+1)
   end

   return s
end

function getHumanReadableInterfaceName(interface_name)
   local key = 'ntopng.prefs.'..interface_name..'.name'
   local custom_name = ntop.getCache(key)

   if not isEmptyString(custom_name) then
      return(shortenCollapse(custom_name))
   else
      interface.select(interface_name)
      local _ifstats = interface.getStats()

      local nm = _ifstats.name
      if(string.contains(nm, "{")) then -- Windows
	 nm = _ifstats.description
      end

      -- print(interface_name.."=".._ifstats.name)
      return(shortenCollapse(nm or ''))
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

function unescapeHTML(s)
   local unesc = function (h)
      local res = string.char(tonumber(h, 16))
      return res
   end

   -- s = string.gsub(s, "+", " ")
   s = string.gsub(s, "%%(%x%x)", unesc)

   return s
end

-- ##############################################

function harvestUnusedDir(path, min_epoch)
   local files = ntop.readdir(path)

   -- print("Reading "..path.."<br>\n")

   for k,v in pairs(files) do
      if(v ~= nil) then
	 local p = os_utils.fixPath(path .. "/" .. v)
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
      local _ifstats = interface.getStats()
      local dirs = ntop.getDirs()
      local basedir = os_utils.fixPath(dirs.workingdir .. "/" .. _ifstats.id)

      harvestUnusedDir(os_utils.fixPath(basedir .. "/top_talkers"), when)
      harvestUnusedDir(os_utils.fixPath(basedir .. "/flows"), when)
   end
end

 -- ##############################################

function haveAdminPrivileges()
   if(isAdministrator()) then
      return(true)
   else
      page_utils.print_header()
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
      return("<i class='fas fa-lock' alt='Safe Protocol'></i>")
   elseif(breed == "Acceptable") then
      return("<i class='fas fa-thumbs-up' alt='Acceptable Protocol'></i>")
   elseif(breed == "Fun") then
      return("<i class='fas fa-smile' alt='Fun Protocol'></i>")
   elseif(breed == "Unsafe") then
      return("<i class='fas fa-thumbs-down'></i>")
   elseif(breed == "Dangerous") then
      return("<i class='fas fa-exclamation-triangle'></i>")
   else
      return("")
   end
end

function getFlag(country)
   if((country == nil) or (country == "")) then
      return("")
   else
      return(" <A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country=".. country .."'><img src='".. ntop.getHttpPrefix() .. "/img/blank.gif' class='flag flag-".. string.lower(country) .."'></A> ")
   end
end

-- GENERIC UTILS

-- split
function split(s, delimiter)
   result = {};
   if(s ~= nil) then
      for match in (s..delimiter):gmatch("(.-)"..delimiter) do
	 table.insert(result, match);
      end
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
function getPasswordInputPattern()
  -- maximum len must be kept in sync with MAX_PASSWORD_LEN
  return [[^[\w\$\\!\/\(\)= \?\^\*@_\-\u0000-\u0019\u0021-\u00ff]{5,31}$]]
end

-- NOTE: keep in sync with validateLicense()
function getLicensePattern()
  return [[^[a-zA-Z0-9\+/=]+$]]
end

function getIPv4Pattern()
  return "^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$"
end

function getACLPattern()
  local ipv4 = "(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])"
  local netmask = "(\\/([0-9]|[1-2][0-9]|3[0-2]))"
  local cidr = ipv4..netmask
  local yesorno_cidr = "[\\+\\-]"..cidr
  return "^"..yesorno_cidr.."(,"..yesorno_cidr..")*$"
end

function getMacPattern()
  return "^([0-9a-fA-F][0-9a-fA-F]:){5}[0-9a-fA-F]{2}$"
end

function getURLPattern()
  return "^https?://.+$"
end

-- get_mac_classification
function get_mac_classification(m, extended_name)
   local short_extended = ntop.getMacManufacturer(m) or {}

   if extended_name then
      return short_extended.extended or short_extended.short or m
   else
      return short_extended.short or m
   end

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

function macInfo(mac)
  return(' <A HREF="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='.. mac ..'">'..mac..'</A> ')
end

-- get_symbolic_mac
function get_symbolic_mac(mac_address, only_symbolic)
   if(magic_macs[mac_address] ~= nil) then
      return(magic_macs[mac_address])
   else
      local m = string.sub(mac_address, 1, 8)
      local t = string.sub(mac_address, 10, 17)

      if(magic_short_macs[m] ~= nil) then
	 if(only_symbolic == true) then
	    return(magic_short_macs[m].."_"..t)
	 else
	    return(magic_short_macs[m].."_"..t.." ("..macInfo(mac_address)..")")
	 end
      else
	 local s = get_mac_classification(m)

	 if(m == s) then
	    return '<a href="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='..mac_address..'">' .. get_mac_classification(m) .. ":" .. t .. '</a>'
	 else
	    if(only_symbolic == true) then
	       return(get_mac_classification(m).."_"..t)
	    else
	       return(get_mac_classification(m).."_"..t.." ("..macInfo(mac_address)..")")
	    end
	 end
      end
   end
end

function get_manufacturer_mac(mac_address)
  local m = string.sub(mac_address, 1, 8)
  local ret = get_mac_classification(m, true --[[ extended name --]])

  if(ret == m) then ret = "n/a" end

  if ret and ret ~= "" then
     ret = ret:gsub("'"," ")
  end

  return ret or "n/a"
end

-- getservbyport
function getservbyport(port_num, proto)
   if(proto == nil) then proto = "TCP" end

   port_num = tonumber(port_num)

   proto = string.lower(proto)

   -- io.write(port_num.."@"..proto.."\n")
   return(ntop.getservbyport(port_num, proto))
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

-- removes trailing/leading spaces
function trimString(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- ###############################################

-- removes all spaces
function trimSpace(what)
   if(what == nil) then return("") end
   return(string.gsub(string.gsub(what, "%s+", ""), "+%s", ""))
end

-- ###############################################

-- TODO: improve this function
function jsonencode(what)
   what = string.gsub(what, '"', "'")
   -- everything but all ASCII characters from the space to the tilde
   what = string.gsub(what, "[^ -~]", " ")
   -- cleanup line feeds and carriage returns
   what = string.gsub(what, "\n", " ")
   what = string.gsub(what, "\r", " ")
   -- escape all the remaining backslashes
   what = string.gsub(what, "\\", "\\\\")
   -- max 1 sequential whitespace
   what = string.gsub(what, " +"," ")
   return(what)
end

-- ###############################################

function formatWebSite(site)
   return("<A target=\"_blank\" HREF=\"http://"..site.."\">"..site.."</A> <i class=\"fas fa-external-link-alt\"></i></th>")
end

-- ###############################################

function formatElephantFlowStatus(flowstatus_info, local2remote)
   local threshold = ""
   local res = ""

   if not flowstatus_info then
      return i18n("flow_details.elephant_flow")
   end

   if local2remote then
      res = i18n("flow_details.elephant_flow_l2r")

      if flowstatus_info["elephant.l2r_threshold"] then
	 threshold = flowstatus_info["elephant.l2r_threshold"]
      end
   else
      res = i18n("flow_details.elephant_flow_r2l")

      if flowstatus_info["elephant.r2l_threshold"] then
	 threshold = flowstatus_info["elephant.r2l_threshold"]
      end
   end

   res = string.format("%s<sup><i class='fas fa-info-circle' aria-hidden='true' title='"..i18n("flow_details.elephant_flow_descr").."'></i></sup>", res)

   if threshold ~= "" then
      res = string.format("%s [%s]", res, i18n("flow_details.elephant_exceeded", {vol = bytesToSize(threshold)}))
   end

   return res
end

-- ###############################################

-- prints purged information for hosts / flows
function purgedErrorString()
    local info = ntop.getInfo(false)
    return i18n("purged_error_message",{url=ntop.getHttpPrefix()..'/lua/admin/prefs.lua?tab=in_memory', product=info["product"]})
end

-- print TCP flags
function printTCPFlags(flags)
   if(hasbit(flags,0x01)) then print('<span class="badge badge-info">FIN</span> ') end
   if(hasbit(flags,0x02)) then print('<span class="badge badge-info">SYN</span> ')  end
   if(hasbit(flags,0x04)) then print('<span class="badge badge-danger">RST</span> ') end
   if(hasbit(flags,0x08)) then print('<span class="badge badge-info">PUSH</span> ') end
   if(hasbit(flags,0x10)) then print('<span class="badge badge-info">ACK</span> ')  end
   if(hasbit(flags,0x20)) then print('<span class="badge badge-info">URG</span> ')  end
   if(hasbit(flags,0x40)) then print('<span class="badge badge-info">ECE</span> ')  end
   if(hasbit(flags,0x80)) then print('<span class="badge badge-info">CWR</span> ')  end
end

-- convert the integer carrying TCP flags in a more convenient lua table
function TCPFlags2table(flags)
   local res = {
      ["FIN"] = 0, ["SYN"] = 0, ["RST"] = 0,
      ["PSH"] = 0, ["ACK"] = 0, ["URG"] = 0,
      ["ECE"] = 0, ["CWR"] = 0,
   }

   if(hasbit(flags,0x01)) then res["FIN"] = 1 end
   if(hasbit(flags,0x02)) then res["SYN"] = 1 end
   if(hasbit(flags,0x04)) then res["RST"] = 1 end
   if(hasbit(flags,0x08)) then res["PSH"] = 1 end
   if(hasbit(flags,0x10)) then res["ACK"] = 1 end
   if(hasbit(flags,0x20)) then res["URG"] = 1 end
   if(hasbit(flags,0x40)) then res["ECE"] = 1 end
   if(hasbit(flags,0x80)) then res["CWR"] = 1 end
   return res
end

-- ##########################################

function historicalProtoHostHref(ifId, host, l4_proto, ndpi_proto_id, info)
   if ntop.isPro() and ntop.getPrefs().is_dump_flows_to_mysql_enabled == true then
      local hist_url = ntop.getHttpPrefix().."/lua/pro/db_explorer.lua?search=true&ifid="..ifId
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
      -- print('<span class="badge badge-info">')
      print('<a href="'..hist_url..'&epoch_begin='..tostring(ago1h)..'" title="Flows seen in the last hour"><i class="fas fa-history fa-lg"></i></a>')
      -- print('</span>')
   end
end

-- #############################################

-- Add here the icons you guess based on the Mac address
-- TODO move to discovery stuff
local guess_icon_keys = {
  ["dell inc."] = "fas fa-desktop",
  ["vmware, inc."] = "fas fa-desktop",
  ["xensource, inc."] = "fas fa-desktop",
  ["lanner electronics, inc."] = "fas fa-desktop",
  ["nexcom international co., ltd."] = "fas fa-desktop",
  ["apple, inc."] = "fab fa-apple",
  ["cisco systems, inc"] = "fas fa-arrows-alt",
  ["juniper networks"] = "fas fa-arrows-alt",
  ["brocade communications systems, inc."] = "fas fa-arrows-alt",
  ["force10 networks, inc."] = "fas fa-arrows-alt",
  ["huawei technologies co.,ltd"] = "fas fa-arrows-alt",
  ["alcatel-lucent ipd"] = "fas fa-arrows-alt",
  ["arista networks, inc."] = "fas fa-arrows-alt",
  ["3com corporation"] = "fas fa-arrows-alt",
  ["routerboard.com"] = "fas fa-arrows-alt",
  ["extreme networks"] = "fas fa-arrows-alt",
  ["xerox corporation"] = "fas fa-print"
}

function guessHostIcon(key)
   local m = string.lower(get_manufacturer_mac(key))
   local icon = guess_icon_keys[m]

   if((icon ~= nil) and (icon ~= "")) then
      return(" <i class='"..icon.." fa-lg'></i>")
   else
      return ""
   end
end

-- ####################################################

-- Functions to set/get a device type of user choice

local function getCustomDeviceKey(mac)
   return "ntopng.prefs.device_types." .. string.upper(mac)
end

function getCustomDeviceType(mac)
   return tonumber(ntop.getPref(getCustomDeviceKey(mac)))
end

function setCustomDeviceType(mac, device_type)
   ntop.setPref(getCustomDeviceKey(mac), tostring(device_type))
end

-- ####################################################

function tableToJsObject(lua_table)
   local json = require("dkjson")
   return json.encode(lua_table, nil)
end

-- ####################################################

function getTzOffsetSeconds()
   local now = os.time()
   local local_t = os.date("*t", now)
   local utc_t = os.date("!*t", now)
   local delta = os.time(local_t) - os.time(utc_t)

   if utc_t.isdst then
      -- DST is the practice of advancing clocks during summer months
      -- so that evening daylight lasts longer, while sacrificing normal sunrise times.
      -- utc_t is increased by one hour when the time is DST.
      -- For example, an UTC time of 2pm would be reported by lua as 3pm with
      -- the isdst flag set.
      -- For this reason, we need to add back the hour to the computed delta.
      delta = delta + 3600
   end

   -- tprint(string.format("local_t %u [%s][isdst: %s]", os.time(local_t), formatEpoch(os.time(local_t)), local_t.isdst))
   -- tprint(string.format("utc_t   %u [%s][isdst: %s]", os.time(utc_t), formatEpoch(os.time(utc_t)), utc_t.isdst))

   return delta
end

-- ####################################################

function makeTimeStamp(d, tzoffset)
   -- tzoffset is the timezone difference between UTC and Local Time in the browser
   local pattern = "(%d+)%/(%d+)%/(%d+) (%d+):(%d+):(%d+)"
   local day,month, year, hour, minute, seconds = string.match(d, pattern);

   local timestamp = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=seconds});

   -- tprint(string.format("pre-timestamp is %u [%s]", timestamp, formatEpoch(timestamp)))
   if tzoffset then
      -- from browser local time to UTC
      timestamp = timestamp - (tzoffset or 0)

      -- from UTC to machine local time
      local delta = getTzOffsetSeconds()

      timestamp = math.floor(timestamp + (delta or 0))
      -- tprint("delta: "..delta.." tzoffset is: "..tzoffset)
      -- tprint(string.format("post-timestamp is %u [%s]", timestamp, formatEpoch(timestamp)))
   end

   return string.format("%u", timestamp)
end

-- ###########################################

-- Merges table a and table b into a new table. If some elements are presents in
-- both a and b, b elements will have precedence.
-- NOTE: this does *not* perform a deep merge. Only first level is merged.
function table.merge(a, b)
  local merged = {}
  a = a or {}
  b = b or {}

  if((a[1] ~= nil) and (b[1] ~= nil)) then
    -- index based tables
    for _, t in ipairs({a, b}) do
       for _,v in pairs(t) do
         merged[#merged + 1] = v
       end
   end
  else
     -- key based tables
     for _, t in ipairs({a, b}) do
       for k,v in pairs(t) do
         merged[k] = v
       end
     end
  end

  return merged
end

-- Performs a deep copy of the table.
function table.clone(orig)
   local orig_type = type(orig)
   local copy

   if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
         copy[table.clone(orig_key)] = table.clone(orig_value)
      end
      setmetatable(copy, table.clone(getmetatable(orig)))
   else -- number, string, boolean, etc
      copy = orig
   end

   return copy
end

-- From http://lua-users.org/lists/lua-l/2014-09/msg00421.html
-- Returns true if tables are equal
function table.compare(t1, t2, ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)

  if ty1 ~= ty2 then return false end
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end

  for k1,v1 in pairs(t1) do
      local v2 = t2[k1]
      if v2 == nil or not table.compare(v1, v2) then return false end
  end

  for k2,v2 in pairs(t2) do
      local v1 = t1[k2]
      if v1 == nil or not table.compare(v1, v2) then return false end
  end

  return true
end

function toboolean(s)
  if((s == "true") or (s == true)) then
    return true
  elseif((s == "false") or (s == false)) then
    return false
  else
    return nil
  end
end

--
-- Find the highest divisor which divides input value.
-- val_idx can be used to index divisors values.
-- Returns the highest_idx
--
function highestDivisor(divisors, value, val_idx, iterator_fn)
  local highest_idx = nil
  local highest_val = nil
  iterator_fn = iterator_fn or ipairs

  for i, v in iterator_fn(divisors) do
    local cmp_v
    if val_idx ~= nil then
      v = v[val_idx]
    end

    if((highest_val == nil) or ((v > highest_val) and (value % v == 0))) then
      highest_val = v
      highest_idx = i
    end
  end

  return highest_idx
end

-- ###########################################

-- Note: the base unit is Kbit/s here
FMT_TO_DATA_RATES_KBPS = {
   ["k"] = {label="kbit/s", value=1},
   ["m"] = {label="Mbit/s", value=1000},
   ["g"] = {label="Gbit/s", value=1000*1000},
}

FMT_TO_DATA_BYTES = {
  ["b"] = {label="B",  value=1},
  ["k"] = {label="KB", value=1024},
  ["m"] = {label="MB", value=1024*1024},
  ["g"] = {label="GB", value=1024*1024*1024},
}

FMT_TO_DATA_TIME = {
  ["s"] = {label=i18n("metrics.secs"),  value=1},
  ["m"] = {label=i18n("metrics.mins"),  value=60},
  ["h"] = {label=i18n("metrics.hours"), value=3600},
  ["d"] = {label=i18n("metrics.days"),  value=3600*24},
}

-- ###########################################

-- Note: use data-min and data-max to setup ranges
function makeResolutionButtons(fmt_to_data, ctrl_id, fmt, value, extra, max_val)
  local extra = extra or {}
  local html_lines = {}

  local divisors = {}

  -- fill in divisors
  if tonumber(value) ~= nil then
    -- foreach character in format
    string.gsub(fmt, ".", function(k)
      local v = fmt_to_data[k]
      if v ~= nil then
	 divisors[#divisors + 1] = {k=k, v=v.value}
      end
    end)
  end

  local selected = nil
  if tonumber(value) ~= 0 then
    selected = highestDivisor(divisors, value, "v")
  end

  if selected ~= nil then
    selected = divisors[selected].k
  else
    selected = string.sub(fmt, 1, 1)
  end

  local style = table.merge({display="flex"}, extra.style or {})
  html_lines[#html_lines+1] = [[<div class="btn-group btn-group-toggle ]] .. table.concat(extra.classes or {}, "") .. [[" id="]] .. ctrl_id .. [[" data-toggle="buttons" style="]] .. table.tconcat(style, ":", "; ", ";") .. [[">]]

  -- foreach character in format
  string.gsub(fmt, ".", function(k)
    local v = fmt_to_data[k]
    if v ~= nil then
       local line = {}

       if((max_val == nil) or (v.value < max_val)) then
	  line[#line+1] = [[<label class="btn]]
	  if selected == k then
	     line[#line+1] = [[ btn-primary active]]
	  else
	     line[#line+1] = [[ btn-secondary]]
	  end
	  line[#line+1] = [[ btn-sm"><input data-resol="]] .. k .. [[" value="]] .. truncate(v.value) .. [[" title="]] .. v.label .. [[" name="opt_resbt_]] .. k .. [[_]] .. ctrl_id .. [[" autocomplete="off" type="radio"]]
	  if selected == k then line[#line+1] = [[ checked="checked"]] end
	  line[#line+1] = [[/>]] .. v.label .. [[</label>]]

	  html_lines[#html_lines+1] = table.concat(line, "")
       end
    end
  end)

  html_lines[#html_lines+1] = [[</div>]]

  -- Note: no // comment below, only /* */

  local js_init_code = [[
      var _resol_inputs = [];

      function resol_selector_get_input(a_button) {
        return $("input", $(a_button).closest(".form-group")).last();
      }

      function resol_selector_get_buttons(an_input) {
        return $(".btn-group", $(an_input).closest(".form-group")).first().find("input");
      }

      /* This function scales values wrt selected resolution */
      function resol_selector_reset_input_range(selected) {
        var selected = $(selected);
        var input = resol_selector_get_input(selected);

        var raw = parseInt(input.attr("data-min"));
        if (! isNaN(raw))
          input.attr("min", Math.sign(raw) * Math.ceil(Math.abs(raw) / selected.val()));

        raw = parseInt(input.attr("data-max"));
        if (! isNaN(raw))
          input.attr("max", Math.sign(raw) * Math.ceil(Math.abs(raw) / selected.val()));

        var step = parseInt(input.attr("data-step-" + selected.attr("data-resol")));
        if (! isNaN(step)) {
          input.attr("step", step);

          /* Align value */
          input.val(input.val() - input.val() % step);
        } else
          input.attr("step", "");

        resol_recheck_input_range(input);
      }

      function resol_selector_change_selection(selected) {
         selected.attr('checked', 'checked')
          .closest("label").removeClass('btn-secondary').addClass('btn-primary')
          .siblings().removeClass('active').removeClass('btn-primary').addClass('btn-secondary').find("input").removeAttr('checked');

        resol_selector_reset_input_range(selected);
      }

      function resol_recheck_input_range(input) {
        var value = input.val();

        if (input[0].hasAttribute("min"))
          value = Math.max(value, input.attr("min"));
        if (input[0].hasAttribute("max"))
          value = Math.min(value, input.attr("max"));

        var old_val = input.val();
        if ((old_val != "") && (old_val != value))
          input.val(value);
      }

      function resol_selector_change_callback(event) {
        resol_selector_change_selection($(this));
      }

      function resol_selector_on_form_submit(event) {
        var form = $(this);

        if (event.isDefaultPrevented() || (form.find(".has-error").length > 0))
          return false;

        resol_selector_finalize(form);
        return true;
      }

      /* Helper function to set a selector value by raw value */
      function resol_selector_set_value(input_id, its_value) {
         var input = $(input_id);
         var buttons = resol_selector_get_buttons($(input_id));
         var values = [];

         buttons.each(function() {
            values.push(parseInt($(this).val()));
         });

         var new_value;
         var new_i;
         if (its_value > 0) {
            /* highest divisor */
            var highest_i = 0;
            for (var i=1; i<values.length; i++) {
              if(((values[i] > values[highest_i]) && (its_value % values[i] == 0)))
                highest_i = i;
            }

            new_value = its_value / values[highest_i];
            new_i = highest_i;
         } else {
            /* smallest value */
            new_value = Math.max(its_value, -1);
            new_i = values.indexOf(Math.min.apply(Math, values));
         }

         /* Set */
         input.val(new_value);
         resol_selector_change_selection($(buttons[new_i]));

         /* This must be set manually on initialization */
         $(buttons[new_i]).closest("label").addClass("active");
      }

      function resol_selector_get_raw(input) {
         var buttons = resol_selector_get_buttons(input);
         var selected = buttons.filter(":checked");

         return parseInt(selected.val()) * parseInt(input.val());
      }

      function resol_selector_finalize(form) {
        $.each(_resol_inputs, function(i, elem) {
          /* Skip elements which are not part of the form */
          if (! $(elem).closest("form").is(form))
            return;

          var selected = $(elem).find("input[checked]");
          var input = resol_selector_get_input(selected);
          resol_recheck_input_range(input);

          /* transform in raw units */
          var new_input = $("<input type=\"hidden\"/>");
          new_input.attr("name", input.attr("name"));
          input.removeAttr("name");
          new_input.val(resol_selector_get_raw(input));
          new_input.appendTo(form);
        });

        /* remove added input names */
        $("input[name^=opt_resbt_]", form).removeAttr("name");
      }]]

  local js_specific_code = [[
    $("#]] .. ctrl_id .. [[ input").change(resol_selector_change_callback);
    $(function() {
      var elemid = "#]] .. ctrl_id .. [[";
      _resol_inputs.push(elemid);
      var selected = $(elemid + " input[checked]");
      resol_selector_reset_input_range(selected);

      /* setup the form submit callback (only once) */
      var form = selected.closest("form");
      if (! form.attr("data-options-handler")) {
        form.attr("data-options-handler", 1);
        form.submit(resol_selector_on_form_submit);
      }
    });
  ]]

  -- join strings and strip newlines
  local html = string.gsub(table.concat(html_lines, ""), "\n", "")
  js_init_code = string.gsub(js_init_code, "\n", "")
  js_specific_code = string.gsub(js_specific_code, "\n", "")

  if tonumber(value) ~= nil then
     -- returns the new value with selected resolution
    return {html=html, init=js_init_code, js=js_specific_code, value=tonumber(value) / fmt_to_data[selected].value}
  else
    return {html=html, init=js_init_code, js=js_specific_code, value=nil}
  end
end

-- ###########################################

--
-- Extracts parameters from a lua table.
-- This function performs the inverse conversion of javascript paramsPairsEncode.
--
-- Note: plain parameters (not encoded with paramsPairsEncode) remain unchanged only
-- when strict mode is *not* enabled
--
function paramsPairsDecode(params, strict_mode)
   local res = {}

   for k,v in pairs(params) do
      local sp = split(k, "key_")
      if #sp == 2 then
         local keyid = sp[2]
         local value = "val_"..keyid
         if params[value] then
            res[v] = params[value]
         end
      end

      if((not strict_mode) and (res[v] == nil)) then
         -- this is a plain parameter
         res[k] = v
      end
   end

   return res
end

function isBridgeInterface(ifstats)
  return ifstats.inline
end

function hasSnmpDevices(ifid)
  if (not ntop.isEnterprise()) or (not isAdministrator()) then
    return false
  end

  return has_snmp_devices(ifid)
end

function getTopFlowPeers(hostname_vlan, max_hits, detailed, other_options)
  local detailed = detailed or false

  local paginator_options = {
    sortColumn = "column_bytes",
    a2zSortOrder = false,
    detailedResults = detailed,
    maxHits = max_hits,
  }

  if other_options ~= nil then
    paginator_options = table.merge(paginator_options, other_options)
  end

  local res = interface.getFlowsInfo(hostname_vlan, paginator_options)
  if ((res ~= nil) and (res.flows ~= nil)) then
    return res.flows
  else
    return {}
  end
end

function stripVlan(name)
  local key = string.split(name, "@")
  if(key ~= nil) then
     return(key[1])
  else
     return(name)
  end
end

function getSafeChildIcon()
   return("&nbsp;<font color='#5cb85c'><i class='fas fa-lg fa-child' aria-hidden='true'></i></font>")
end

-- ###########################################

function printntopngRelease(info)
   if info.oem then
      return ""
   end

   if(info["version.enterprise_edition"]) or (info["version.nedge_enterprise_edition"]) then
      print(" Enterprise")
   elseif(info["version.nedge_edition"]) then
      print(" ")
   elseif(info["pro.release"]) then
      print(" Professional")
   else
      print(" Community")
   end

   if(info["version.embedded_edition"] == true) then
      print("/Embedded")
   end

   print(" Edition</td></tr>\n")
end

-- ###########################################

-- avoids manual HTTP prefix and /lua concatenation
function page_url(path)
  return ntop.getHttpPrefix().."/lua/"..path
end

-- extracts a page url from the path
function path_get_page(path)
   local prefix = ntop.getHttpPrefix() .. "/lua/"

   if string.find(path, prefix) == 1 then
      return string.sub(path, string.len(prefix) + 1)
   end

   return path
end

-- ###########################################

function swapKeysValues(tbl)
   local new_tbl = {}

   for k, v in pairs(tbl or {}) do
      new_tbl[v] = k
   end

   return new_tbl
end

-- ###########################################

-- A redis hash mac -> first_seen
function getFirstSeenDevicesHashKey(ifid)
   return "ntopng.seen_devices.ifid_" .. ifid
end

-- ###########################################

function getHideFromTopSet(ifid)
   return "ntopng.prefs.iface_" .. ifid .. ".hide_from_top"
end

-- ###########################################

function printWarningAlert(message)
   print[[<div class="alert alert-warning alert-dismissable" role="alert">]]
   print[[<a class="close" data-dismiss="alert" aria-label="close">&times;</a>]]
   print[[<i class="fas fa-exclamation-triangle fa-sm"></i> ]]
   print[[<strong>]] print(i18n("warning")) print[[</strong> ]]
   print(message)
   print[[</div>]]
end

-- ###########################################

function tsQueryToTags(query)
   local tags = {}

   for _, part in pairs(split(query, ",")) do
      local sep_pos = string.find(part, ":")

      if sep_pos then
         local k = string.sub(part, 1, sep_pos-1)
         local v = string.sub(part, sep_pos+1)
         tags[k] = v
      end
   end

   return tags
end

function tsTagsToQuery(tags)
   return table.tconcat(tags, ":", ",")
end

-- ###########################################

function splitUrl(url)
   local params = {}
   local parts = split(url, "?")

   if #parts == 2 then
      url = parts[1]
      parts = split(parts[2], "&")

      for _, param in pairs(parts) do
         local p = split(param, "=")

         if #p == 2 then
            params[p[1]] = p[2]
         end
      end
   end

   return {
      url = url,
      params = params,
   }
end

-- ###########################################

function getDeviceProtocolPoliciesUrl(params_str)
   local url, sep

   if ntop.isnEdge() then
      url = "/lua/pro/nedge/admin/nf_edit_user.lua?page=device_protocols"
      sep = "&"
   else
      url = "/lua/admin/edit_device_protocols.lua"
      sep = "?"
   end

   if not isEmptyString(params_str) then
      return ntop.getHttpPrefix() .. url .. sep .. params_str
   end

   return ntop.getHttpPrefix() .. url
end

-- ###########################################

-- Banner format: {type="success|warning|danger", text="..."}
function printMessageBanners(banners)
   for _, msg in ipairs(banners) do
      print[[
  <div class="alert alert-]] print(msg.type) print([[ alert-dismissible" style="margin-top:2em; margin-bottom:0em;">
    <button type="button" class="close" data-dismiss="alert" aria-label="]]..i18n("close")..[[">
      <span aria-hidden="true">&times;</span>
    </button>]])

      if (msg.type == "warning") then
         print("<b>".. i18n("warning") .. "</b>: ")
      elseif (msg.type == "danger") then
         print("<b>".. i18n("error") .. "</b>: ")
      end

      print(msg.text)
    
      print[[
  </div>]]
   end
end

-- ###########################################

function visualTsKey(tskey)
   if ends(tskey, "_v4") or ends(tskey, "_v6") then
      local ver = string.sub(tskey, string.len(tskey)-1, string.len(tskey))
      local address = string.sub(tskey, 1, string.len(tskey)-3)
      local visual_addr

      if ver == "v4" then
         visual_addr = address
      else
         visual_addr = address .. " (" .. ver ..")"
      end

      return visual_addr
   end

   return tskey
end

-- ###########################################

-- Returns the size of a folder (size is in bytes)
function getFolderSize(path)
   local size = 0

   if ntop.isWindows() then
     -- TODO
   else
      if ntop.isdir(path) then
         local line = os_utils.execWithOutput("du -s "..path.." 2>/dev/null")
         local values = split(line, '\t')
         if #values >= 1 then
            local used = tonumber(values[1])
            if used ~= nil then
               size = used*1024
            end
         end
      end
   end

   return size
end

-- ###########################################

function getHttpUrlPrefix()
   if starts(_SERVER["HTTP_HOST"], 'https://') then
      return "https://"
   else
      return "http://"
   end
end

-- ###########################################

-- Compares IPv4 / IPv6 addresses
function ip_address_asc(a, b)
   return(ntop.ipCmp(a, b) < 0)
end

function ip_address_rev(a, b)
   return(ntop.ipCmp(a, b) > 0)
end

-- ###########################################

-- @brief Deletes all the cache/prefs keys matching the pattern
function deleteCachePattern(pattern)
   local keys = ntop.getKeysCache(pattern)

   for key in pairs(keys or {}) do
      ntop.delCache(key)
   end
end

-- ###########################################

--
-- IMPORTANT
-- Leave it at the end so it can use the functions
-- defined in this file
--
http_lint = require "http_lint"
