--
-- (C) 2014-18 - ntop.org
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
local alert_consts = require "alert_consts"

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
maxRateToString = format_utils.maxRateToString
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
   local ifnames = interface.getIfNames()
   local iface = ifnames[tostring(interface_id)]

   if iface ~= nil then
      if(windows_skip_description ~= true and string.contains(iface, "{")) then -- Windows
         local old_iface = interface.getStats().id

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
   local ifnames = interface.getIfNames()

   for if_id, if_name in pairs(ifnames) do
      return tonumber(if_id), if_name
   end

   return -1, "" -- NOTREACHED
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

function sendHTTPHeaderIfName(mime, ifname, maxage, content_disposition, extra_headers)
  info = ntop.getInfo(false)
  local cookie_attr = ntop.getCookieAttributes()

  print('HTTP/1.1 200 OK\r\n')
  print('Cache-Control: max-age=0, no-cache, no-store\r\n')
  print('Server: ntopng '..info["version"]..' ['.. info["platform"]..']\r\n')
  print('Pragma: no-cache\r\n')
  print('X-Frame-Options: DENY\r\n')
  print('X-Content-Type-Options: nosniff\r\n')
  if(_SESSION ~= nil) then print('Set-Cookie: session='.._SESSION["session"]..'; max-age=' .. maxage .. '; path=/; ' .. cookie_attr .. '\r\n') end
  if(ifname ~= nil) then print('Set-Cookie: ifname=' .. ifname .. '; path=/' .. cookie_attr .. '\r\n') end
  print('Content-Type: '.. mime ..'\r\n')
  if(content_disposition ~= nil) then print('Content-Disposition: '..content_disposition..'\r\n') end
  if type(extra_headers) == "table" then
     for hname, hval in pairs(extra_headers) do
	print(hname..': '..hval..'\r\n')
     end
  end
  print('Last-Modified: '..os.date("!%a, %m %B %Y %X %Z").."\r\n")
  print('\r\n')
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

-- Simplified checker
function isIPv6Address(ip)
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

function printASN(asn, asname)
  asname = asname:gsub('"','')
  if(asn > 0) then
    return("<A HREF='http://as.robtex.com/as"..asn..".html' title='"..asname.."'>"..asname.."</A> <i class='fa fa-external-link fa-lg'></i>")
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
      ipversion_filter = '<span class="glyphicon glyphicon-filter"></span>'
   else
      ipversion_filter = ''
   end
   local ipversion_params = table.clone(page_params)
   ipversion_params["version"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.ip_version")) print[[]] print(ipversion_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(base_url, ipversion_params)) print[[">]] print(i18n("flows_page.all_ip_versions")) print[[</a></li>\
         <li]] if ipversion == "4" then print(' class="active"') end print[[><a href="]] ipversion_params["version"] = "4"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv4_only")) print[[</a></li>\
         <li]] if ipversion == "6" then print(' class="active"') end print[[><a href="]] ipversion_params["version"] = "6"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv6_only")) print[[</a></li>\
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
      vlan_id_filter = '<span class="glyphicon glyphicon-filter"></span>'
   end

   local vlan_id_params = table.clone(page_params)
   vlan_id_params["vlan"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.vlan")) print[[]] print(vlan_id_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">]] print(i18n("flows_page.all_vlan_ids")) print[[</a></li>\]]
   for _, vid in ipairs(ids) do
      vlan_id_params["vlan"] = vid
      print[[
         <li>\
           <a href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">VLAN ]] print(tostring(vid)) print[[</a></li>\]]
   end
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
      cur_dev_filter = '<span class="glyphicon glyphicon-filter"></span>'
   end

   local dev_params = table.clone(page_params)
   for _, p in pairs({"deviceIP", "outIfIdx", "inIfIdx"}) do
      dev_params[p] = nil
   end

   print[[, '<div class="btn-group pull-right">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page.device_ip")) print[[]] print(cur_dev_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(base_url, dev_params)) print[[">]] print(i18n("flows_page.all_devices")) print[[</a></li>\]]
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
           <a href="]] print(getPageUrl(base_url, dev_params)) print[[">]] print(i18n("flows_page.device_ip").." "..dip) print[[</a></li>\]]
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
	    cur_if_filter = '<span class="glyphicon glyphicon-filter"></span>'
	 end

	 local if_params = table.clone(page_params)

	 if_params[direction] = nil
	    print[[, '<div class="btn-group pull-right">\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("flows_page."..direction)) print[[]] print(cur_if_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
         <li><a href="]] print(getPageUrl(base_url, if_params)) print[[">]] print(i18n("flows_page.all_"..direction)) print[[</a></li>\]]

	    for portidx, _ in pairsByKeys(ports, asc) do
	       if_params[direction] = portidx
	       print[[
         <li>\
           <a href="]] print(getPageUrl(base_url, if_params)) print[[">]] print(i18n("flows_page."..direction).." "..tostring(portidx)) print[[</a></li>\]]
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

function l4_proto_to_string(proto_id)
   proto_id = tonumber(proto_id)

   for _, proto in pairs(l4_keys) do
      if proto[3] == proto_id then
         return proto[1], proto[2]
      end
   end

   return nil
end

-- ##############################################

-- Note: make sure the maximum id for checkpoint_keys honours CONST_MAX_NUM_CHECKPOINTS
local checkpoint_keys = {
   -- following checkpoints are used for alerts
   {0, "min"},
   {1, "5mins"},
   {2, "hour"},
   {3, "day"},
}

function checkpointId(v)
   local checkpointtable = {}
   for i, t in ipairs(checkpoint_keys) do
      checkpointtable[#checkpointtable + 1] = {t[1], t[2]}
   end
   return(_handleArray(checkpointtable, v))
end

function noHtml(s)
   if s == nil then return nil end
   local cleaned = s:gsub("<[aA].->(.-)</[aA]>","%1")
      :gsub("%s*<[iI].->(.-)</[iI]>","%1")
      :gsub("<.->(.-)</.->","%1") -- note: this does not handle nested tags
      :gsub("^%s*(.-)%s*$", "%1")
   return cleaned
end

function alertSeverityLabel(v, nohtml)
   local res = _handleArray(alert_consts.alert_severity_keys, tonumber(v))
   if res ~= nil and nohtml == true then res = noHtml(res) end
   return res
end

function alertSeverity(v)
   local severity_table = {}
   for i, t in ipairs(alert_consts.alert_severity_keys) do
      severity_table[#severity_table + 1] = {t[2], t[3]}
   end
   return(_handleArray(severity_table, v))
end

function alertSeverityRaw(sev_idx)
   sev_idx = sev_idx + 2 -- -1 and 0
   if sev_idx <= #alert_consts.alert_severity_keys then
      return alert_consts.alert_severity_keys[sev_idx][3]
   end
   return nil
end

function alertTypeLabel(v, nohtml)
   local res = _handleArray(alert_consts.alert_type_keys, tonumber(v))
   if res ~= nil and nohtml == true then res = noHtml(res) end
   return res
end

function alertType(v)
   local typetable = {}
   for i, t in ipairs(alert_consts.alert_type_keys) do
      typetable[#typetable + 1] = {t[2], t[3]}
   end
   return(_handleArray(typetable, v))
end

function alertEngine(v)
   local enginetable = {}
   for i, t in ipairs(alert_consts.alert_functions_description) do
      enginetable[#enginetable + 1] = {t[2], t[3]}
   end
   return(_handleArray(enginetable, v))
end

function alertEngineLabel(v)
   return _handleArray(alert_consts.alert_functions_description, tonumber(v))
end

function alertEngineRaw(idx)
   idx = idx + 1
   if idx <= #alert_consts.alert_functions_description then
      return alert_consts.alert_functions_description[idx][3]
   end
   return nil
end

function alertLevel(v)
   local leveltable = {}

   for i, t in ipairs(alert_consts.alert_severity_keys) do
      leveltable[#leveltable + 1] = {t[2], t[3]}
   end
   return(_handleArray(leveltable, v))
end

function alertTypeRaw(alert_idx)
   if(alert_idx == nil) then return nil end

   alert_idx = alert_idx + 2 -- -1 and 0
   if alert_idx <= #alert_consts.alert_type_keys then
      return alert_consts.alert_type_keys[alert_idx][3]
   end
   return nil
end

function alertEntityLabel(v, nothml)
   local res = _handleArray(alert_consts.alert_entity_keys, tonumber(v))
   if res ~= nil and nohtml == true then res = noHtml(res) end
   return res
end

function alertEntity(v)
   local typetable = {}
   for i, t in ipairs(alert_consts.alert_entity_keys) do
      typetable[#typetable + 1] = {t[2], t[3]}
   end
   return(_handleArray(typetable, v))
end

function alertEntityRaw(entity_idx)
   entity_idx = entity_idx + 1
   if entity_idx <= #alert_consts.alert_entity_keys then
      return alert_consts.alert_entity_keys[entity_idx][3]
   end
   return nil
end

function areAlertsEnabled()
  return (ntop.getPref("ntopng.prefs.disable_alerts_generation") ~= "1")
end

function mustScanAlerts(ifstats)
   -- can't alert on view interfaces as checkpoints will collide for their underlying real interfaces
   return areAlertsEnabled() and not ifstats["isView"]
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

--for _key, _value in pairsByKeys(vals, rev) do
--   print(_key .. "=" .. _value .. "\n")
--end

function round(num, idp)
   if(num == nil) then return(0) end
   return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end
--function round(num) return math.floor(num+.5) end

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
  local chunks = {address:match("(%d+)%.(%d+)%.(%d+)%.(%d+)$")}

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
       <div id="]] print(name) print [[" class="progress-bar progress-bar-warning"></div>
  </div>
  ]]
  if(url ~= nil) then print('</A>\n') end

end

-- Compute the difference in seconds between local time and UTC.
function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
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

function hostVisualization(ip, name)
   if (ip ~= name) and isIPv6(ip) then
      return name.." [IPv6]"
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
   return hostVisualization(hostinfo["host"], hostname)
end

-- #################################

function getResolvedAddress(hostinfo)
   local hostname = ntop.getResolvedName(hostinfo["host"])
   return hostVisualization(hostinfo["host"], hostname)
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

function getOSIcon(name)
  icon = ""

  if(findString(name, "Linux") or findString(name, "Ubuntu")) then icon = '<i class=\'fa fa-linux fa-lg\'></i> '
  elseif(findString(name, "Android")) then icon = '<i class=\'fa fa-android fa-lg\'></i> '
  elseif(findString(name, "Windows") or findString(name, "Win32") or findString(name, "MSIE")) then icon = '<i class=\'fa fa-windows fa-lg\'></i> '
  elseif(findString(name, "iPhone") or findString(name, "iPad") or findString(name, "OS X") ) then icon = '<i class=\'fa fa-apple fa-lg\'></i> '
  end

  return(icon)
end

-- #################################

function getOperatingSystemName(id)
   if(id == 1) then return("Linux")
   elseif(id == 2) then return("Windows")
   elseif(id == 3) then return("MacOS")
   elseif(id == 4) then return("iOS")
   elseif(id == 5) then return("Android")
   elseif(id == 6) then return("LaserJET")
   elseif(id == 7) then return("AppleAirport")
   else
      return("") -- Unknown
   end
end

-- #################################

function getOperatingSystemIcon(id)
   if(id == 1) then return(' <i class=\'fa fa-linux fa-lg\'></i>')
   elseif(id == 2) then return(' <i class=\'fa fa-windows fa-lg\'></i>')
   elseif(id == 3) then return(' <i class=\'fa fa-apple fa-lg\'></i>')
   elseif(id == 4) then return(' <i class=\'fa fa-apple fa-lg\'></i>')
   elseif(id == 5) then return(' <i class=\'fa fa-android fa-lg\'></i>')
   elseif(id == 6) then return(' LasetJET')
   elseif(id == 7) then return(' Apple Airport')

   else return("")
   end
end

-- #################################

function getApplicationIcon(name)
  local icon = ""
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

  return(icon)
end

-- #################################

function getApplicationLabel(name)
  local icon = getApplicationIcon(name)

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

function splitNetworkPrefix(net)
   local prefix = tonumber(net:match("/(.+)"))
   local address = net:gsub("/.+","")
   return address, prefix
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
      rname = getResolvedAddress({host=name, vlan=vlan})

      if((rname ~= nil) and (rname ~= "")) then
	 name = rname
      end
   end

   if(vlan > 0) then
      name = name .. '@' .. vlan
   end

   return name
end

function flowinfo2hostname(flow_info, host_type)
   local name
   local orig_name

   if(host_type == "srv") then
      if(flow_info["host_server_name"] ~= nil and flow_info["host_server_name"] ~= "") then
	 return(flow_info["host_server_name"])
      end
      if(flow_info["protos.ssl.certificate"] ~= nil and flow_info["protos.ssl.certificate"] ~= "") then
	 return(flow_info["protos.ssl.certificate"])
      end
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
    elseif(host_info["name"] ~= nil) then
      rsp = rsp..'host='..host_info["name"]
    elseif(host_info["mac"] ~= nil) then
      rsp = rsp..'host='..host_info["mac"]
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

function get_version_update_msg(info, latest_version)
  version_elems = split(info["version"], " ")
  new_version = version2int(latest_version)
  this_version = version2int(version_elems[1])

  if(new_version > this_version) then
   return [[<div class='alert alert-warning'><font color=red><i class='fa fa-cloud-download fa-lg'></i> A new ]]..info["product"]..[[ (v.]]..(latest_version)..[[) is available for <A HREF='http://www.ntop.org/get-started/download/'>download</A>: please upgrade.</font></div>]]
  else
   return ""
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
   return isAdministrator() and not nbox_integration and interface.isPacketInterface() and not ntop.isnEdge()
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

local function getCustomnDPIProtoCategoriesKey(ifid)
   return getRedisIfacePrefix(ifid)..".custom_nDPI_proto_categories"
end

function getCustomnDPIProtoCategories(if_name)
   local ifid = getInterfaceId(if_name)
   local ndpi_protos = interface.getnDPIProtocols()
   local key = getCustomnDPIProtoCategoriesKey(ifid)

   local res = {}
   for _, app_id in pairs(ndpi_protos) do
      local custom_category = ntop.getHashCache(key, tostring(app_id))
      if not isEmptyString(custom_category) then
	 res[tonumber(app_id)] = tonumber(custom_category)
      end
   end

   return res
end

function initCustomnDPIProtoCategories()
   for _, ifname in pairs(interface.getIfNames()) do
      interface.select(ifname)
      local custom = getCustomnDPIProtoCategories(ifname)

      for app_id, cat_id in pairs(custom) do
	 interface.setnDPIProtoCategory(app_id, cat_id)
      end
   end
end

function setCustomnDPIProtoCategory(if_name, app_id, new_cat_id)
   interface.select(if_name)
   interface.setnDPIProtoCategory(app_id, new_cat_id)

   local ifid = getInterfaceId(if_name)
   local key = getCustomnDPIProtoCategoriesKey(ifid)

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

function unescapeHTML (s)
   local unesc = function (h)
      local res = string.char(tonumber(h, 16))
      return res
   end

   s = string.gsub(s, "+", " ")
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

function isAdministrator()
   local user_group = ntop.getUserGroup()

   if(user_group == "administrator") or (user_group == "") then
      return(true)
   else
      return(false)
   end
end

 -- ##############################################

function haveAdminPrivileges()
   if(isAdministrator()) then
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
  return [[^[\w\$\\!\/\(\)=\?\^\*@_\-\u0000-\u0019\u0021-\u00ff]{5,}$]]
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
   return("<A target=\"_blank\" HREF=\"http://"..site.."\">"..site.."</A> <i class=\"fa fa-external-link\"></i></th>")
end

-- Update Utils::flowstatus2str
function getFlowStatus(status)
  if(status == 0) then return("<font color=green>"..i18n("flow_details.normal").."</font>")
  elseif(status == 1)  then return("<font color=orange>"..i18n("flow_details.slow_tcp_connection").."</font>")
  elseif(status == 2)  then return("<font color=orange>"..i18n("flow_details.slow_application_header").."</font>")
  elseif(status == 3)  then return("<font color=orange>"..i18n("flow_details.slow_data_exchange").."</font>")
  elseif(status == 4)  then return("<font color=orange>"..i18n("flow_details.low_goodput").."</font>")
  elseif(status == 5)  then return("<font color=orange>"..i18n("flow_details.suspicious_tcp_syn_probing").."</font>")
  elseif(status == 6)  then return("<font color=orange>"..i18n("flow_details.tcp_connection_issues").."</font>")
  elseif(status == 7)  then return("<font color=orange>"..i18n("flow_details.suspicious_tcp_probing").."</font>")
  elseif(status == 8)  then return("<font color=orange>"..i18n("flow_details.flow_emitted").."</font>")
  elseif(status == 9)  then return("<font color=orange>"..i18n("flow_details.tcp_connection_refused").."</font>")
  elseif(status == 10) then return("<font color=orange>"..i18n("flow_details.ssl_certificate_mismatch").."</font>")
  elseif(status == 11) then return("<font color=orange>"..i18n("flow_details.dns_invalid_query").."</font>")
  elseif(status == 12) then return("<font color=orange>"..i18n("flow_details.remote_to_remote").."</font>")
  elseif(status == 13) then return("<font color=orange>"..i18n("flow_details.blacklisted_flow").."</font>")
  elseif(status == 14) then return(""..i18n("flow_details.flow_blocked_by_bridge").."")
  elseif(status == 15) then return(""..i18n("flow_details.web_mining_detected").."")
  else return("<font color=orange>"..i18n("flow_details.unknown_status",{status=status}).."</font>")
  end
end

-- prints purged information for hosts / flows
function purgedErrorString()
    local info = ntop.getInfo(false)
    return i18n("purged_error_message",{url=ntop.getHttpPrefix()..'/lua/admin/prefs.lua?tab=in_memory', product=info["product"]})
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

-- convert the integer carrying TCP flags in a more convenient lua table
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
      -- print('<span class="label label-info">')
      print('<a href="'..hist_url..'&epoch_begin='..tostring(ago1h)..'" title="Flows seen in the last hour"><i class="fa fa-history fa-lg"></i></a>')
      -- print('</span>')
   end
end

-- ##########################################

_icmp_types = {
	 { 0, 0, i18n("icmp_v4_types.type_0_0_echo_reply") },
	 { 3, 0, i18n("icmp_v4_types.type_3_0_network_unreachable") },
	 { 3, 1, i18n("icmp_v4_types.type_3_1_host_unreachable") },
	 { 3, 2, i18n("icmp_v4_types.type_3_2_protocol_unreachable") },
	 { 3, 3, i18n("icmp_v4_types.type_3_3_port_unreachable") },
	 { 3, 4, i18n("icmp_v4_types.type_3_4_fragmentation_needed_but_no_fragment_bit_set") },
	 { 3, 5, i18n("icmp_v4_types.type_3_5_source_routing_failed") },
	 { 3, 6, i18n("icmp_v4_types.type_3_6_destination_network_unknown") },
	 { 3, 7, i18n("icmp_v4_types.type_3_7_destination_host_unknown") },
	 { 3, 8, i18n("icmp_v4_types.type_3_8_source_host_isolated") },
	 { 3, 9, i18n("icmp_v4_types.type_3_9_destination_network_administratively_prohibited") },
	 { 3, 10, i18n("icmp_v4_types.type_3_10_destination_host_administratively_prohibited") },
	 { 3, 11, i18n("icmp_v4_types.type_3_11_network_unreachable_for_tos") },
	 { 3, 12, i18n("icmp_v4_types.type_3_12_host_unreachable_for_tos") },
	 { 3, 13, i18n("icmp_v4_types.type_3_13_communication_administratively_prohibited_by_filtering") },
	 { 3, 14, i18n("icmp_v4_types.type_3_14_host_precedence_violation") },
	 { 3, 15, i18n("icmp_v4_types.type_3_15_precedence_cutoff_in_effect") },
	 { 4, 0, i18n("icmp_v4_types.type_4_0_source_quench") },
	 { 5, 0, i18n("icmp_v4_types.type_5_0_redirect_for_network") },
	 { 5, 1, i18n("icmp_v4_types.type_5_1_redirect_for_host") },
	 { 5, 2, i18n("icmp_v4_types.type_5_2_redirect_for_tos_and_network") },
	 { 5, 3, i18n("icmp_v4_types.type_5_3_redirect_for_tos_and_host") },
	 { 8, 0, i18n("icmp_v4_types.type_8_0_echo_request_x") },
	 { 9, 0, i18n("icmp_v4_types.type_9_0_router_advertisement") },
	 { 10, 0, i18n("icmp_v4_types.type_10_0_route_solicitation") },
	 { 11, 0, i18n("icmp_v4_types.type_11_0_ttl_equals_0_during_transit") },
	 { 11, 1, i18n("icmp_v4_types.type_11_1_ttl_equals_0_during_reassembly") },
	 { 12, 0, i18n("icmp_v4_types.type_12_0_ip_header_bad") },
	 { 12, 1, i18n("icmp_v4_types.type_12_1_required_options_missing") },
	 { 13, 0, i18n("icmp_v4_types.type_13_0_timestamp_request") },
	 { 14, 0, i18n("icmp_v4_types.type_14_0_timestamp_reply") },
	 { 15, 0, i18n("icmp_v4_types.type_15_0_information_request") },
	 { 16, 0, i18n("icmp_v4_types.type_16_0_information_reply") },
	 { 17, 0, i18n("icmp_v4_types.type_17_0_address_mask_request") },
	 { 18, 0, i18n("icmp_v4_types.type_18_0_address_mask_reply") }
}

-- Code is currently ignored on IVMPv6
_icmpv6_types = {
        { 0, i18n("icmp_v6_types.type_0_reserved") },
	{ 1, i18n("icmp_v6_types.type_1_destination_unreachable") },
	{ 2, i18n("icmp_v6_types.type_2_packet_too_big") },
	{ 3, i18n("icmp_v6_types.type_3_time_exceeded") },
	{ 4, i18n("icmp_v6_types.type_4_parameter_problem") },
	{ 100, i18n("icmp_v6_types.type_100_private_experimentation") },
	{ 101, i18n("icmp_v6_types.type_101_private_experimentation") },
	--{ 102-126, i18n("icmp_v6_types.type_102-126_unassigned") },
	{ 127, i18n("icmp_v6_types.type_127_reserved_for_expansion_of_icmpv6_error_messages") },
	{ 128, i18n("icmp_v6_types.type_128_echo_request") },
	{ 129, i18n("icmp_v6_types.type_129_echo_reply") },
	{ 130, i18n("icmp_v6_types.type_130_multicast_listener_query") },
	{ 131, i18n("icmp_v6_types.type_131_multicast_listener_report") },
	{ 132, i18n("icmp_v6_types.type_132_multicast_listener_done") },
	{ 133, i18n("icmp_v6_types.type_133_router_solicitation") },
	{ 134, i18n("icmp_v6_types.type_134_router_advertisement") },
	{ 135, i18n("icmp_v6_types.type_135_neighbor_solicitation") },
	{ 136, i18n("icmp_v6_types.type_136_neighbor_advertisement") },
	{ 137, i18n("icmp_v6_types.type_137_redirect_message") },
	{ 138, i18n("icmp_v6_types.type_138_router_renumbering") },
	{ 139, i18n("icmp_v6_types.type_139_icmp_node_information_query") },
	{ 140, i18n("icmp_v6_types.type_140_icmp_node_information_response") },
	{ 141, i18n("icmp_v6_types.type_141_inverse_neighbor_discovery_solicitation_message") },
	{ 142, i18n("icmp_v6_types.type_142_inverse_neighbor_discovery_advertisement_message") },
	{ 143, i18n("icmp_v6_types.type_143_version_2_multicast_listener_report") },
	{ 144, i18n("icmp_v6_types.type_144_home_agent_address_discovery_request_message") },
	{ 145, i18n("icmp_v6_types.type_145_home_agent_address_discovery_reply_message") },
	{ 146, i18n("icmp_v6_types.type_146_mobile_prefix_solicitation") },
	{ 147, i18n("icmp_v6_types.type_147_mobile_prefix_advertisement") },
	{ 148, i18n("icmp_v6_types.type_148_certification_path_solicitation_message") },
	{ 149, i18n("icmp_v6_types.type_149_certification_path_advertisement_message") },
	{ 150, i18n("icmp_v6_types.type_150_icmp_messages_utilized_by_experimental_mobility_protocols") },
	{ 151, i18n("icmp_v6_types.type_151_multicast_router_advertisement") },
	{ 152, i18n("icmp_v6_types.type_152_multicast_router_solicitation") },
	{ 153, i18n("icmp_v6_types.type_153_multicast_router_termination") },
	{ 154, i18n("icmp_v6_types.type_154_fmipv6_messages") },
	{ 155, i18n("icmp_v6_types.type_155_rpl_control_message") },
	{ 156, i18n("icmp_v6_types.type_156_ilnpv6_locator_update_message") },
	{ 157, i18n("icmp_v6_types.type_157_duplicate_address_request") },
	{ 158, i18n("icmp_v6_types.type_158_duplicate_address_confirmation") },
	{ 159, i18n("icmp_v6_types.type_159_mpl_control_message") },
	--{ 160-199, i18n("icmp_v6_types.type_160-199_unassigned") },
	{ 200, i18n("icmp_v6_types.type_200_private_experimentation") },
	{ 201, i18n("icmp_v6_types.type_201_private_experimentation") },
	{ 255, i18n("icmp_v6_types.type_255_reserved_for_expansion_of_icmpv6_informational_messages") }
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

-- #############################################

-- Add here the icons you guess based on the Mac address
-- TODO move to discovery stuff
local guess_icon_keys = {
  ["dell inc."] = "fa-desktop",
  ["vmware, inc."] = "fa-desktop",
  ["xensource, inc."] = "fa-desktop",
  ["lanner electronics, inc."] = "fa-desktop",
  ["nexcom international co., ltd."] = "fa-desktop",
  ["apple, inc."] = "fa-apple",
  ["cisco systems, inc"] = "fa-arrows",
  ["juniper networks"] = "fa-arrows",
  ["brocade communications systems, inc."] = "fa-arrows",
  ["force10 networks, inc."] = "fa-arrows",
  ["huawei technologies co.,ltd"] = "fa-arrows",
  ["alcatel-lucent ipd"] = "fa-arrows",
  ["arista networks, inc."] = "fa-arrows",
  ["3com corporation"] = "fa-arrows",
  ["routerboard.com"] = "fa-arrows",
  ["extreme networks"] = "fa-arrows",
  ["xerox corporation"] = "fa-print"
}

function guessHostIcon(key)
   local m = string.lower(get_manufacturer_mac(key))
   local icon = guess_icon_keys[m]

   if((icon ~= nil) and (icon ~= "")) then
      return(" <i class='fa "..icon.." fa-lg'></i>")
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

function makeTimeStamp(d, tzoffset)
   -- tzoffset is the timezone difference between UTC and Local Time in the browser
   local pattern = "(%d+)%/(%d+)%/(%d+) (%d+):(%d+):(%d+)"
   local day,month, year, hour, minute, seconds = string.match(d, pattern);

   local timestamp = os.time({year=year, month=month, day=day, hour=hour, min=minute, sec=seconds});

   -- tprint("pre-timestamp is:"..timestamp)
   if tzoffset then
      -- from browser local time to UTC
      timestamp = timestamp - (tzoffset or 0)

      -- from UTC to machine local time
      local now = os.time()
      local local_t = os.date("*t", now)
      local utc_t = os.date("!*t", now)
      local delta = (local_t.hour - utc_t.hour)*60 + (local_t.min - utc_t.min)
      delta = delta * 60 -- to seconds

      timestamp = timestamp + (delta or 0)
      -- tprint("delta: "..delta.." tzoffset is: "..tzoffset)
      -- tprint("post-timestamp is:"..timestamp)
   end

   return timestamp.."";
end

-- ###########################################

-- IMPORTANT: keep it in sync with sortField (ntop_typedefs.h)
--            AND host_search_walker:NetworkInterface.cpp
--            AND NetworkInterface::getFlows()
looking_glass_criteria = {
   -- KEY  LABEL   Host::lua()-label  formatting
   { "uploaders", i18n("uploaders"), "upload", bytesToSize },
   { "downloaders", i18n("downloaders"), "download", bytesToSize },
   { "unknowers", i18n("unknowers"), "unknown", bytesToSize },
   { "incomingflows", i18n("incomingflows"), "incomingflows", format_utils.formatValue },
   { "outgoingflows", i18n("outgoingflows"), "outgoingflows", format_utils.formatValue },
}

function criteria2label(criteria)
  local id

  for id, _ in ipairs(looking_glass_criteria) do
    local key   = looking_glass_criteria[id][1]
    local label = looking_glass_criteria[id][2]
    local fnctn = looking_glass_criteria[id][4]

    if(key == criteria) then
      return label, fnctn
    end
  end

  return criteria, format_utils.formatValue
end

function label2criteriakey(what)
  local id

  for id, _ in ipairs(looking_glass_criteria) do
    local c        = looking_glass_criteria[id][1]
    local key      = looking_glass_criteria[id][3]
    local fnctn    = looking_glass_criteria[id][4]

    if(what == c) then
       return key, fnctn
    end
  end

  return what, format_utils.formatValue
end

function table.merge(a, b)
  local merged = {}

  for _, t in ipairs({a, b}) do
    for k,v in pairs(t) do
      merged[k] = v
    end
  end

  return merged
end

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
  if s == "true" then
    return true
  elseif s == "false" then
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
function makeResolutionButtons(fmt_to_data, ctrl_id, fmt, value, extra)
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
  html_lines[#html_lines+1] = [[<div class="btn-group ]] .. table.concat(extra.classes or {}, "") .. [[" id="]] .. ctrl_id .. [[" data-toggle="buttons" style="]] .. table.tconcat(style, ":", "; ", ";") .. [[">]]

  -- foreach character in format
  string.gsub(fmt, ".", function(k)
    local v = fmt_to_data[k]
    if v ~= nil then
      local line = {}
      line[#line+1] = [[<label class="btn]]
      if selected == k then
	 line[#line+1] = [[ btn-primary active]]
      else
	 line[#line+1] = [[ btn-default]]
      end
      line[#line+1] = [[ btn-sm"><input data-resol="]] .. k .. [[" value="]] .. v.value .. [[" title="]] .. v.label .. [[" name="opt_resbt_]] .. k .. [[_]] .. ctrl_id .. [[" autocomplete="off" type="radio"]]
      if selected == k then line[#line+1] = [[ checked="checked"]] end
      line[#line+1] = [[/>]] .. v.label .. [[</label>]]

      html_lines[#html_lines+1] = table.concat(line, "")
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
          .closest("label").removeClass('btn-default').addClass('btn-primary')
          .siblings().removeClass('active').removeClass('btn-primary').addClass('btn-default').find("input").removeAttr('checked');

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

function hasBridgeInterfaces(skip_netfilter)
  local curif = ifname
  local ifnames = interface.getIfNames()
  local found = false

  for _,ifname in pairs(ifnames) do
    interface.select(ifname)

    local ifstats = interface.getStats()
    if isBridgeInterface(ifstats)
        and (skip_netfilter~=true or ifstats.type ~= "netfilter") then
      found = true
      break
    end
  end

  interface.select(curif)
  return found
end

-- Returns true if the captive portal can be started with the current configuration
function isCaptivePortalSupported(ifstats, prefs, skip_interface_check)
   if not ntop.isEnterprise() and not ntop.isnEdge() then
      return false
   end

   local is_bridge_iface

   if not skip_interface_check then
      local ifstats = ifstats or interface.getStats()
      is_bridge_iface = isBridgeInterface(ifstats)
   else
      is_bridge_iface = true
   end

   local prefs = prefs or ntop.getPrefs()
   return is_bridge_iface and (prefs["http.port"] ~= 80)
end

-- Returns true if the captive portal is active right now
function isCaptivePortalActive(ifstats, prefs)
  if not ntop.isEnterprise() then
    return false
  end

  local ifstats = ifstats or interface.getStats()
  local prefs = prefs or ntop.getPrefs()
  local is_bridge_iface = isBridgeInterface(ifstats)

  return is_bridge_iface and prefs["is_captive_portal_enabled"] and isCaptivePortalSupported(ifstats, prefs)
end

function getCaptivePortalUsers()
  local keys = ntop.getKeysCache("ntopng.user.*.host_pool_id")
  local users = {}

  for key in pairs(keys or {}) do
    local host_pool = ntop.getCache(key)

    if not isEmptyString(host_pool) then
      local username = split(key, "%.")[3]
      users[username] = host_pool
    end
  end

  return users
end

function getBridgeInitializedKey(ifid)
  return "ntopng.prefs.iface_"..ifid..".bridge_initialized"
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
   return("&nbsp;<font color='#5cb85c'><i class='fa fa-lg fa-child' aria-hidden='true'></i></font>")
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
   print[[<i class="fa fa-warning fa-sm"></i> ]]
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

--
-- IMPORTANT
-- Leave it at the end so it can use the functions
-- defined in this file
--
http_lint = require "http_lint"

