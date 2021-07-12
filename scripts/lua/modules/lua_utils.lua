--
-- (C) 2014-21 - ntop.org
--

-- Hack to avoid include loops

if(pragma_once_lua_utils == true) then
   -- avoid multiple inclusions
   return
end

pragma_once_lua_utils = true

-- ###############################################

dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/i18n/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/flow_dbms/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_trace"
require "ntop_utils"
locales_utils = require "locales_utils"
local os_utils = require "os_utils"
local format_utils = require "format_utils"
local dscp_consts = require "dscp_consts"
local tag_utils = require "tag_utils"

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
function string.contains(str, start, is_plain)
   if type(str) ~= 'string' or type(start) ~= 'string' then
      return false
   end

   local i, _ = string.find(str, start, 1, is_plain)

   return(i ~= nil)
end

-- ##############################################

function shortenString(name, max_len)
   local ellipsis = "\u{2026}" -- The unicode ellipsis (takes less space than three separate dots)
   if(name == nil) then return("") end

   if max_len == nil then
      max_len = ntop.getPref("ntopng.prefs.max_ui_strlen")
      max_len = tonumber(max_len)
      if(max_len == nil) then max_len = 24 end
   end

   if(string.len(name) < max_len + 1 --[[ The space taken by the ellipsis --]]) then
      return(name)
   else
      return(string.sub(name, 1, max_len)..ellipsis)
   end
end

-- ##############################################

function convertDate(vardate)
    local m,d,y,h,i,s = string.match(vardate, '(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)')
    return string.format('%s/%s/%s %s:%s:%s', d,m,y,h,i,s)
end

-- ##############################################

-- See also getHumanReadableInterfaceName
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

local cached_allowed_networks_set = nil

function hasAllowedNetworksSet()
   if(cached_allowed_networks_set == nil) then
      local nets = ntop.getAllowedNetworks()
      local allowed_nets = string.split(nets, ",") or {nets}
      cached_allowed_networks_set = false

      for _, net in pairs(allowed_nets) do
         if((not isEmptyString(net)) and (net ~= "0.0.0.0/0") and (net ~= "::/0")) then
            cached_allowed_networks_set = true
            break
         end
      end
   end

   return(cached_allowed_networks_set)
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

-- See Utils::l4proto2name()
l4_keys = {
   { "IP",        "ip",          0 },
   { "ICMP",      "icmp",        1 },
   { "IGMP",      "igmp",        2 },
   { "TCP",       "tcp",         6 },
   { "UDP",       "udp",        17 },

   { "IPv6",      "ipv6",       41 },
   { "RSVP",      "rsvp",       46 },
   { "GRE",       "gre",        47 },
   { "ESP",       "esp",        50 },
   { "IPv6-ICMP", "ipv6icmp",   58 },
   { "OSPF",      "ospf",       89 },
   { "PIM",       "pim",       103 },
   { "VRRP",      "vrrp",      112 },
   { "HIP",       "hip",       139 },
   { "ICMPv6",    "icmpv6",     58 },
   { "IGMP",      "igmp",        2 },
   { "Other IP",  "other_ip",   -1 }
}

L4_PROTO_KEYS = {
   tcp=6,
   udp=17,
   icmp=1,
   other_ip=-1
}

function __FILE__() return debug.getinfo(2,'S').source end
function __LINE__() return debug.getinfo(2, 'l').currentline end

-- ##############################################

local http_status_code_map = {
  [200] = "OK",
  [400] = "Bad Request",
  [401] = "Unauthorized",
  [403] = "Forbidden",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [406] = "Not Acceptable",
  [408] = "Request timeout",
  [409] = "Conflict",
  [410] = "Gone",
  [412] = "Precondition Failed",
  [415] = "Unsupported Media Type",
  [423] = "Locked",
  [428] = "Precondition Required",
  [429] = "Too many requests",
  [500] = "Internal Server Error",
  [501] = "Not Implemented",
  [503] = "Service Unavailable",
}

-- ##############################################

function sendHTTPHeaderIfName(mime, ifname, maxage, content_disposition, extra_headers, status_code)
   info = ntop.getInfo(false)
   -- tprint(info)
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
      local key = "session_"..info.http_port.."_"..info.https_port
      lines[#lines + 1] = 'Set-Cookie: '..key..'='.._SESSION["session"]..'; max-age=' .. maxage .. '; path=/; ' .. cookie_attr
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

   if not status_code then
      status_code = 200
   end

   local status_descr = http_status_code_map[status_code]
   if not status_descr then
      status_descr = "Unknown"
   end

   -- Buffer the HTTP reply and write it in one "print" to avoid fragmenting
   -- it into multiple packets, to ease HTTP debugging with wireshark.
   print("HTTP/1.1 " .. status_code .. " " .. status_descr .. "\r\n" .. table.concat(lines, "\r\n") .. "\r\n\r\n")
end

-- ##############################################

function sendHTTPHeaderLogout(mime, content_disposition)
  sendHTTPHeaderIfName(mime, nil, 0, content_disposition)
end

-- ##############################################

function sendHTTPHeader(mime, content_disposition, extra_headers, status_code)
   sendHTTPHeaderIfName(mime, nil, 3600, content_disposition, extra_headers, status_code)
end

-- ##############################################

function sendHTTPContentTypeHeader(content_type, content_disposition, charset, extra_headers, status_code)
  local charset = charset or "utf-8"
  local mime = content_type.."; charset="..charset

  sendHTTPHeader(mime, content_disposition, extra_headers, status_code)
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

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local ipversion_params = table.clone(page_params)
   ipversion_params["version"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.ip_version")) print[[]] print(ipversion_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, ipversion_params)) print[[">]] print(i18n("flows_page.all_ip_versions")) print[[</a></li>\
         <li><a class="dropdown-item ]] if ipversion == "4" then print('active') end print[[" href="]] ipversion_params["version"] = "4"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv4_only")) print[[</a></li>\
         <li><a class="dropdown-item ]] if ipversion == "6" then print('active') end print[[" href="]] ipversion_params["version"] = "6"; print(getPageUrl(base_url, ipversion_params)); print[[">]] print(i18n("flows_page.ipv6_only")) print[[</a></li>\
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

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local vlan_id_params = table.clone(page_params)
   vlan_id_params["vlan"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.vlan")) print[[]] print(vlan_id_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">]] print(i18n("flows_page.all_vlan_ids")) print[[</a></li>\]]
   for _, vid in ipairs(ids) do
      vlan_id_params["vlan"] = vid
      print[[
         <li>\
           <a class="dropdown-item ]] print(vlan_id == tostring(vid) and 'active' or '') print[[" href="]] print(getPageUrl(base_url, vlan_id_params)) print[[">VLAN ]] print(tostring(vid)) print[[</a></li>\]]
   end
   print[[

      </ul>]]
end

-- ##############################################

function printDSCPDropdown(base_url, page_params, dscp_list)
   local dscp = _GET["dscp"]
   local dscp_filter
   if not isEmptyString(dscp) then
      dscp_filter = '<span class="fas fa-filter"></span>'
   else
      dscp_filter = ''
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local dscp_params = table.clone(page_params)
   dscp_params["dscp"] = nil
   -- Used to possibly remove tcp state filters when selecting a non-TCP l4 protocol
   local dscp_params_non_filter = table.clone(dscp_params)
   if dscp_params_non_filter["dscp"] then
      dscp_params_non_filter["dscp"] = nil
   end

   local ordered_dscp_list = {}

   for key, value in pairs(dscp_list) do
      local name = dscp_consts.dscp_descr(key)
      ordered_dscp_list[name] = {}
      ordered_dscp_list[name]["id"] = key
      ordered_dscp_list[name]["count"] = value.count
   end

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.dscp")) print[[]] print(dscp_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu dropdown-menu-end scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, dscp_params_non_filter)) print[[">]] print(i18n("flows_page.all_dscp")) print[[</a></li>]]

   for key, value in pairsByKeys(ordered_dscp_list, asc) do
	  print[[<li]]

	  print([[><a class="dropdown-item ]].. (tonumber(dscp) == value.id and 'active' or '') ..[[" href="]])

	  local dscp_table = ternary(key ~= 6, dscp_params_non_filter, dscp_params)

	  dscp_table["dscp"] = value.id
	  print(getPageUrl(base_url, dscp_table))

	  print[[">]] print(key) print [[ (]] print(string.format("%d", value.count)) print [[)</a></li>]]
   end

   print[[</ul>]]
end

-- ###################################

function printHostPoolDropdown(base_url, page_params, host_pool_list)
   local host_pools = require "host_pools"
   
   local host_pools_instance = host_pools:create()
   local host_pool = _GET["host_pool_id"]
   local host_pool_filter
   if not isEmptyString(host_pool) then
      host_pool_filter = '<span class="fas fa-filter"></span>'
   else
      host_pool_filter = ''
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local host_pool_params = table.clone(page_params)
   host_pool_params["host_pool_id"] = nil
   -- Used to possibly remove tcp state filters when selecting a non-TCP l4 protocol
   local host_pool_params_non_filter = table.clone(host_pool_params)
   if host_pool_params_non_filter["host_pool_id"] then
      host_pool_params_non_filter["host_pool_id"] = nil
   end

   local ordered_host_pool_list = {}

   if host_pool then
      local id = tonumber(host_pool)
      ordered_host_pool_list[id] = {}
      ordered_host_pool_list[id]["count"] = host_pool_list[id]["count"]
   else
      for key, value in pairs(host_pool_list) do
	 ordered_host_pool_list[key] = {}
	 ordered_host_pool_list[key]["count"] = value.count
      end
   end
   
   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("details.host_pool")) print[[]] print(host_pool_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu dropdown-menu-end scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, host_pool_params_non_filter)) print[[">]] print(i18n("flows_page.all_host_pool")) print[[</a></li>]]

   for key, value in pairsByKeys(ordered_host_pool_list, asc) do
      print[[<li]]

      print([[><a class="dropdown-item ]].. (tonumber(host_pool) == key and 'active' or '') ..[[" href="]])
      
      local host_pool_table = ternary(key ~= 6, host_pool_params_non_filter, host_pool_params)
      
      host_pool_table["host_pool_id"] = key
      print(getPageUrl(base_url, host_pool_table))
      
      print[[">]] print(host_pools_instance:get_pool_name(key)) print [[ (]] print(string.format("%d", value.count)) print [[)</a></li>]]
   end

   print[[</ul>]]
end

-- ##############################################

function printTrafficTypeFilterDropdown(base_url, page_params)
   local traffic_type = _GET["traffic_type"]
   local traffic_type_filter = ''
   if not isEmptyString(traffic_type) then
      traffic_type_filter = '<span class="fas fa-filter"></span>'
   end

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local traffic_type_params = table.clone(page_params)
   traffic_type_params["traffic_type"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("flows_page.direction")) print[[]] print(traffic_type_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
         <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_all")) print[[</a></li>\]]

   -- now forthe one-way
   traffic_type_params["traffic_type"] = "one_way"
   print[[
         <li>\
           <a class="dropdown-item ]] if traffic_type == "one_way" then print('active') end print[[" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_one_way")) print[[</a></li>\]]
   traffic_type_params["traffic_type"] = "bidirectional"
   print[[
         <li>\
           <a class="dropdown-item ]] if traffic_type == "bidirectional" then print('active') end print[[" href="]] print(getPageUrl(base_url, traffic_type_params)) print[[">]] print(i18n("hosts_stats.traffic_type_two_ways")) print[[</a></li>\]]
   print[[
      </ul>]]
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
   if not proto_id then return "" end
   if isEmptyString(proto_id) then return "" end

   proto_id = tonumber(proto_id)

   for _, proto in pairs(l4_keys) do
      if proto[3] == proto_id then
         return proto[1], proto[2]
      end
   end

   return string.format("%d", proto_id)
end

-- Return the list of L4 proto (key = name, value = id)
function l4_proto_list()
   local list = {}

   for _, proto in pairs(l4_keys) do
      -- add L4 proto only
      if proto[2] ~= 'ip' and
         proto[2] ~= 'ipv6' then
         list[proto[1]] =  proto[3]
      end
   end

   return list
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

   local cleaned = s:gsub("<[aA] .->(.-)</[aA]>","%1")
      :gsub("<abbr .->(.-)</abbr>","%1")
      :gsub("<span .->(.-)</span>","%1")
      :gsub("%s*<[iI].->(.-)</[iI]>","%1")
      :gsub("<.->(.-)</.->","%1") -- note: keep as last as this does not handle nested tags
      :gsub("^%s*(.-)%s*$", "%1")
      :gsub('&nbsp;', " ")

   return unescape(cleaned)
end

-- ##############################################

function areAlertsEnabled()
   if(__alert_enabled == nil) then
      -- Not too nice as changes will be read periodically as new VMs are reloaded
      -- but at least we avoid breaking up the performance
      __alert_enabled = (ntop.getPref("ntopng.prefs.disable_alerts_generation") ~= "1")
   end

   return (__alert_enabled)
end

-- ##############################################

function isScoreEnabled()
  return(ntop.isEnterpriseM())
end

-- ##############################################

function hasTrafficReport()
   local ts_utils = require("ts_utils_core")
   local is_pcap_dump = interface.isPcapDumpInterface()

   return((not is_pcap_dump) and (ts_utils.getDriverName() == "rrd") and ntop.isEnterpriseM())
end

function mustScanAlerts(ifstats)
   return areAlertsEnabled()
end

function hasAlertsDisabled()
  _POST = _POST or {}
  return ((_POST["disable_alerts_generation"] ~= nil) and (_POST["disable_alerts_generation"] == "1")) or
      ((_POST["disable_alerts_generation"] == nil) and (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1"))
end

function hasNindexSupport()
   local auth = require "auth"

   if not ntop.isPro() or ntop.isWindows() then
      return false
   end

   -- Don't allow nIndex for unauthorized users
   if not auth.has_capability(auth.capabilities.historical_flows) then
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
   local ainfo = interface.getAddressInfo(ip)

   if(ainfo.is_multicast or ainfo.is_broadcast) then
      return true
   else
      return false
   end
end

function isIPv4(address)

   -- Reuse the for loop to check the address validity
   local checkAddress = (function(chunks)
      for _, v in pairs(chunks) do
         if (tonumber(v) < 0) or (tonumber(v) > 255) then
            return false
         end
      end
      return true
   end)

   local chunks = {address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
   local chunksWithPort = {address:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)%:(%d+)$")}

   if #chunks == 4 then
      return checkAddress(chunks)
   elseif #chunksWithPort == 5 then
      table.remove(chunksWithPort, 5)
      return checkAddress(chunksWithPort)
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

function addLogoLightSvg()
   return ([[
      <div id='ntopng-logo'>
         <svg
            id="ntopng-logo"
            data-name="ntopng logo"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 512.74 512.84"
            height="56"
            width="56">
            <defs>
               <style>
                  .cls-1{fill:none;}
                  .cls-2{fill:#cecece;}
                  .cls-2,.cls-3,.cls-4{fill-rule:evenodd;}
                  .cls-3{fill:#b7b7b7;}
                  .cls-4{fill:#ee751b;}
               </style>
            </defs>
            <title>ntopng logo</title>
            <path class="cls-1" d="M1,513.94V1.1H513.78V513.94ZM497.86,172c0-22.84.08-44.16-.07-65.48a100.07,100.07,0,0,0-1.34-16.31c-6.87-40.3-39-71.17-81.23-71.68-105.79-1.27-211.6-.44-317.4-.35a60.46,60.46,0,0,0-14.33,1.62c-39.52,9.78-65.2,42.87-65.34,85-.24,75.82-.07,151.63,0,227.44,0,1.2.25,2.39.47,4.31,2.18-1.71,3.83-2.82,5.26-4.17,14.23-13.54,28.39-27.15,42.67-40.65,2.17-2.06,2.09-3.89,1.38-6.64-1.58-6.05-3.65-12.31-3.45-18.41.91-28.45,25.61-49.36,51.92-48.1,25.77,1.23,50.24,25.65,46.44,55.08-.59,4.64.85,6,4.18,6.6,38.67-46.29,85.62-58.59,141.88-36.58a15.05,15.05,0,0,0,1-1.31c17.37-26.37,34.78-52.72,52-79.21.92-1.42.69-4.55-.28-6.07-9.33-14.54-11.6-29.7-5.46-46.12,8.26-22.11,33.59-36,56.46-30.51,26.38,6.29,42.42,30.41,37.84,57.12-.55,3.25.22,5.15,3.1,6.94,9,5.62,17.81,11.66,26.81,17.34C485.7,165.2,491.33,168.21,497.86,172Zm-87.1,325.77c22.32,1.05,41.19-5.51,57.26-19.17,19-16.16,30.07-36.25,30-62.13-.33-67.15-.11-134.31-.11-201.46v-7.13c-2.44-1.43-4.62-2.59-6.68-3.93-17.43-11.35-34.88-22.65-52.21-34.14-3.45-2.28-6-2.68-9.66,0-10.77,7.8-23.06,9.91-36.05,7.52-3.8-.69-6,.23-8.17,3.57-11.63,18-23.54,35.89-35.31,53.83-5.55,8.46-11,17-16.52,25.5.85.9,1.39,1.52,2,2.09,36.21,34.78,46.28,81.33,27.45,127.7-1.17,2.87-.64,4.43,1.45,6.41q19.77,18.75,39.33,37.71c7.71,7.43,15.11,15.06,17.48,26.13C423.92,474.13,420.3,486.24,410.76,497.74Zm-58.57.12c-16-16.38-31-31.78-46.18-47-1-1-3.94-1.17-5.55-.57a115.89,115.89,0,0,1-53,7c-61.43-6.45-106.54-62-99.74-123.42,1-9,3.34-17.91,5.11-27.08-4.26-3.2-4.21-3.14-8.65.1-16.12,11.79-33.27,13.91-51.71,5.79-1.78-.78-5.22-.36-6.6.91-10.52,9.69-20.74,19.71-31,29.66Q37.1,360.42,19.44,377.69a5.83,5.83,0,0,0-1.3,3.83c-.07,12.5-.27,25,.06,37.48,1.09,41.31,39.69,78.85,80.9,78.85H352.19Zm-92.67-262c-40.78,2.35-73.75,18.09-93.85,55.48-4.3,8-8.56,16.21-11.36,24.81-4.59,14.08-5.25,28.73-3.21,43.46q5.52,39.68,35.05,66.66c18.62,17,40.75,26.23,65.8,28.17A98.42,98.42,0,0,0,301.13,446c3.13-1.44,4.55-1.23,6.73,1,15.72,16.08,31.71,31.91,47.27,48.14,14.32,14.93,38,15,54-1.07,12.43-12.52,12.43-37.07-.58-50.18-8.62-8.7-17.68-17-26.63-25.35-7.53-7-15.19-14-22.78-21-1.8-1.66-3.1-3.34-1.46-6,7.47-12.09,10.36-25.7,10.79-39.49,1.28-41.07-13.57-74.32-49.22-96.78-5.73-3.61-11.25-7.75-17.38-10.52C288.55,238.72,274.35,236,259.52,235.83Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M497.86,172c-6.53-3.76-12.16-6.77-17.56-10.17-9-5.67-17.77-11.72-26.81-17.33-2.88-1.79-3.65-3.69-3.1-6.94,4.58-26.71-11.46-50.84-37.84-57.12-22.87-5.45-48.2,8.4-56.46,30.5-6.14,16.43-3.87,31.58,5.46,46.13,1,1.52,1.19,4.65.28,6.07-17.19,26.49-34.59,52.83-52,79.2a15.5,15.5,0,0,1-1,1.32c-56.27-22-103.21-9.71-141.89,36.58-3.32-.6-4.77-2-4.17-6.6,3.8-29.44-20.67-53.85-46.45-55.08-26.3-1.26-51,19.65-51.91,48.09-.2,6.11,1.87,12.37,3.45,18.42.71,2.75.79,4.58-1.39,6.64-14.27,13.5-28.43,27.11-42.66,40.64-1.43,1.36-3.09,2.47-5.26,4.18-.22-1.92-.47-3.12-.47-4.31,0-75.82-.19-151.63,0-227.44.13-42.12,25.82-75.2,65.34-85a60.46,60.46,0,0,1,14.33-1.62c105.8-.09,211.61-.92,317.4.35,42.2.5,74.36,31.38,81.23,71.67a101.41,101.41,0,0,1,1.34,16.32C497.94,127.81,497.86,149.13,497.86,172Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-3" d="M410.76,497.74c9.54-11.5,13.17-23.61,10.19-37.49-2.37-11.06-9.77-18.7-17.48-26.13q-19.61-18.92-39.33-37.71c-2.09-2-2.62-3.54-1.45-6.41,18.83-46.37,8.76-92.92-27.45-127.7-.59-.57-1.14-1.19-2-2.09,5.51-8.52,11-17,16.52-25.5,11.77-17.94,23.68-35.8,35.31-53.83,2.15-3.34,4.37-4.27,8.17-3.57,13,2.39,25.28.28,36.05-7.52,3.71-2.69,6.21-2.29,9.66,0,17.33,11.48,34.78,22.79,52.21,34.13,2.06,1.35,4.23,2.51,6.68,3.94V215c0,67.15-.22,134.31.11,201.46.12,25.88-11,46-30,62.12C452,492.23,433.08,498.79,410.76,497.74Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-3" d="M352.19,497.86H99.1c-41.21,0-79.81-37.54-80.9-78.85-.33-12.48-.13-25-.06-37.48a5.88,5.88,0,0,1,1.3-3.83q17.61-17.31,35.42-34.43c10.29-9.95,20.51-20,31-29.67,1.37-1.26,4.81-1.68,6.59-.9,18.44,8.12,35.59,6,51.72-5.79,4.43-3.24,4.39-3.3,8.64-.1-1.77,9.17-4.12,18.05-5.11,27.07-6.8,61.43,38.31,117,99.74,123.42a115.75,115.75,0,0,0,53-7c1.61-.6,4.51-.48,5.55.57C321.19,466.08,336.16,481.48,352.19,497.86Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-4" d="M259.52,235.83c14.83.18,29,2.89,42.38,8.92,6.13,2.77,11.65,6.9,17.38,10.51C354.93,277.72,369.79,311,368.5,352c-.43,13.8-3.32,27.41-10.79,39.5-1.64,2.66-.33,4.34,1.47,6,7.59,7,15.24,13.93,22.78,21,8.94,8.38,18,16.65,26.62,25.35,13,13.1,13,37.66.58,50.17-16,16.11-39.71,16-54,1.08-15.57-16.23-31.56-32.06-47.28-48.15-2.18-2.23-3.6-2.43-6.73-1A98.32,98.32,0,0,1,252,454.41c-25-1.94-47.17-11.18-65.8-28.17q-29.52-26.94-35-66.66c-2.05-14.73-1.39-29.38,3.2-43.46,2.81-8.6,7.06-16.8,11.37-24.81C185.77,253.92,218.74,238.18,259.52,235.83Zm74.75,109.92c0-41.77-33.56-74.92-75.46-75.17-43.6-.26-75,36.34-75.13,75.47-.15,42.12,33.35,75.3,75.65,75.23C301.1,421.21,334.32,387.73,334.27,345.75Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-1" d="M334.27,345.75c.05,42-33.17,75.46-74.94,75.53-42.3.07-75.8-33.11-75.65-75.23.15-39.13,31.53-75.73,75.13-75.47C300.71,270.83,334.23,304,334.27,345.75Zm-23.81-51.17C306.21,301,302,307,298.26,313.26a5.89,5.89,0,0,0,.08,5.24c7.05,10,9.43,21,8.85,33-1.21,25.15-26,50.24-57.27,44.86-27-4.64-44.41-28.79-41.21-54.87.19-1.58-.23-4.18-1.28-4.83-5.73-3.55-11.74-6.64-17.77-10-9.73,33.58,7.86,70.39,40,84.81A72.56,72.56,0,0,0,320.85,384C340.92,352,331.39,313.58,310.46,294.58ZM285.84,278.5c-24.8-13.2-67.88-1.62-82.65,22,5.81,3.19,11.73,6.18,17.36,9.64,2.33,1.43,3.62,1.13,5.61-.47,12.3-9.84,26.1-14,41.84-10.79,1.62.33,4.36-.28,5.21-1.45C277.65,291.33,281.66,284.88,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M310.46,294.58c20.93,19,30.46,57.41,10.39,89.43a72.56,72.56,0,0,1-91.19,27.52c-32.14-14.42-49.73-51.23-40-84.81,6,3.32,12,6.41,17.77,10,1,.65,1.47,3.25,1.27,4.83-3.19,26.08,14.25,50.23,41.22,54.87,31.26,5.38,56.06-19.71,57.27-44.86.58-12-1.8-23.06-8.85-33a5.89,5.89,0,0,1-.08-5.24C302,307,306.21,301,310.46,294.58Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M285.84,278.5c-4.18,6.38-8.19,12.83-12.63,19-.85,1.17-3.58,1.78-5.21,1.45-15.74-3.18-29.54.95-41.84,10.79-2,1.6-3.28,1.9-5.61.47-5.63-3.46-11.55-6.45-17.36-9.64C218,276.88,261,265.3,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
         </svg>
      </div>
   ]])
end

function addLogoDarkSvg()
   return ([[
      <div id='ntopng-logo'>
         <svg
            id="ntopng-logo-svg"
            data-name="ntopng logo"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 512.74 512.84"
            height="56"
            width="56">
            <defs>
               <style>
                  .cls-1{fill:none;}
                  .cls-2{fill:#333;}
                  .cls-2,.cls-3{fill-rule:evenodd;}
                  .cls-3{fill:#ee751b;}
               </style>
            </defs>
            <title>ntopng logo</title>
            <path class="cls-1" d="M1,513.94V1.1H513.78V513.94ZM497.86,172c0-22.84.08-44.16-.07-65.48a100.07,100.07,0,0,0-1.34-16.31c-6.87-40.3-39-71.17-81.23-71.68-105.79-1.27-211.6-.44-317.4-.35a60.46,60.46,0,0,0-14.33,1.62c-39.52,9.78-65.2,42.87-65.34,85-.24,75.82-.07,151.63,0,227.44,0,1.2.25,2.39.47,4.31,2.18-1.71,3.83-2.82,5.26-4.17,14.23-13.54,28.39-27.15,42.67-40.65,2.17-2.06,2.09-3.89,1.38-6.64-1.58-6.05-3.65-12.31-3.45-18.41.91-28.45,25.61-49.36,51.92-48.1,25.77,1.23,50.24,25.65,46.44,55.08-.59,4.64.85,6,4.18,6.6,38.67-46.29,85.62-58.59,141.88-36.58a15.05,15.05,0,0,0,1-1.31c17.37-26.37,34.78-52.72,52-79.21.92-1.42.69-4.55-.28-6.07-9.33-14.54-11.6-29.7-5.46-46.12,8.26-22.11,33.59-36,56.46-30.51,26.38,6.29,42.42,30.41,37.84,57.12-.55,3.25.22,5.15,3.1,6.94,9,5.62,17.81,11.66,26.81,17.34C485.7,165.2,491.33,168.21,497.86,172Zm-87.1,325.77c22.32,1.05,41.19-5.51,57.26-19.17,19-16.16,30.07-36.25,30-62.13-.33-67.15-.11-134.31-.11-201.46v-7.13c-2.44-1.43-4.62-2.59-6.68-3.93-17.43-11.35-34.88-22.65-52.21-34.14-3.45-2.28-6-2.68-9.66,0-10.77,7.8-23.06,9.91-36.05,7.52-3.8-.69-6,.23-8.17,3.57-11.63,18-23.54,35.89-35.31,53.83-5.55,8.46-11,17-16.52,25.5.85.9,1.39,1.52,2,2.09,36.21,34.78,46.28,81.33,27.45,127.7-1.17,2.87-.64,4.43,1.45,6.41q19.77,18.75,39.33,37.71c7.71,7.43,15.11,15.06,17.48,26.13C423.92,474.13,420.3,486.24,410.76,497.74Zm-58.57.12c-16-16.38-31-31.78-46.18-47-1-1-3.94-1.17-5.55-.57a115.89,115.89,0,0,1-53,7c-61.43-6.45-106.54-62-99.74-123.42,1-9,3.34-17.91,5.11-27.08-4.26-3.2-4.21-3.14-8.65.1-16.12,11.79-33.27,13.91-51.71,5.79-1.78-.78-5.22-.36-6.6.91-10.52,9.69-20.74,19.71-31,29.66Q37.1,360.42,19.44,377.69a5.83,5.83,0,0,0-1.3,3.83c-.07,12.5-.27,25,.06,37.48,1.09,41.31,39.69,78.85,80.9,78.85H352.19Zm-92.67-262c-40.78,2.35-73.75,18.09-93.85,55.48-4.3,8-8.56,16.21-11.36,24.81-4.59,14.08-5.25,28.73-3.21,43.46q5.52,39.68,35.05,66.66c18.62,17,40.75,26.23,65.8,28.17A98.42,98.42,0,0,0,301.13,446c3.13-1.44,4.55-1.23,6.73,1,15.72,16.08,31.71,31.91,47.27,48.14,14.32,14.93,38,15,54-1.07,12.43-12.52,12.43-37.07-.58-50.18-8.62-8.7-17.68-17-26.63-25.35-7.53-7-15.19-14-22.78-21-1.8-1.66-3.1-3.34-1.46-6,7.47-12.09,10.36-25.7,10.79-39.49,1.28-41.07-13.57-74.32-49.22-96.78-5.73-3.61-11.25-7.75-17.38-10.52C288.55,238.72,274.35,236,259.52,235.83Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M497.86,172c-6.53-3.76-12.16-6.77-17.56-10.17-9-5.67-17.77-11.72-26.81-17.33-2.88-1.79-3.65-3.69-3.1-6.94,4.58-26.71-11.46-50.84-37.84-57.12-22.87-5.45-48.2,8.4-56.46,30.5-6.14,16.43-3.87,31.58,5.46,46.13,1,1.52,1.19,4.65.28,6.07-17.19,26.49-34.59,52.83-52,79.2a15.5,15.5,0,0,1-1,1.32c-56.27-22-103.21-9.71-141.89,36.58-3.32-.6-4.77-2-4.17-6.6,3.8-29.44-20.67-53.85-46.45-55.08-26.3-1.26-51,19.65-51.91,48.09-.2,6.11,1.87,12.37,3.45,18.42.71,2.75.79,4.58-1.39,6.64-14.27,13.5-28.43,27.11-42.66,40.64-1.43,1.36-3.09,2.47-5.26,4.18-.22-1.92-.47-3.12-.47-4.31,0-75.82-.19-151.63,0-227.44.13-42.12,25.82-75.2,65.34-85a60.46,60.46,0,0,1,14.33-1.62c105.8-.09,211.61-.92,317.4.35,42.2.5,74.36,31.38,81.23,71.67a101.41,101.41,0,0,1,1.34,16.32C497.94,127.81,497.86,149.13,497.86,172Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M410.76,497.74c9.54-11.5,13.17-23.61,10.19-37.49-2.37-11.06-9.77-18.7-17.48-26.13q-19.61-18.92-39.33-37.71c-2.09-2-2.62-3.54-1.45-6.41,18.83-46.37,8.76-92.92-27.45-127.7-.59-.57-1.14-1.19-2-2.09,5.51-8.52,11-17,16.52-25.5,11.77-17.94,23.68-35.8,35.31-53.83,2.15-3.34,4.37-4.27,8.17-3.57,13,2.39,25.28.28,36.05-7.52,3.71-2.69,6.21-2.29,9.66,0,17.33,11.48,34.78,22.79,52.21,34.13,2.06,1.35,4.23,2.51,6.68,3.94V215c0,67.15-.22,134.31.11,201.46.12,25.88-11,46-30,62.12C452,492.23,433.08,498.79,410.76,497.74Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M352.19,497.86H99.1c-41.21,0-79.81-37.54-80.9-78.85-.33-12.48-.13-25-.06-37.48a5.88,5.88,0,0,1,1.3-3.83q17.61-17.31,35.42-34.43c10.29-9.95,20.51-20,31-29.67,1.37-1.26,4.81-1.68,6.59-.9,18.44,8.12,35.59,6,51.72-5.79,4.43-3.24,4.39-3.3,8.64-.1-1.77,9.17-4.12,18.05-5.11,27.07-6.8,61.43,38.31,117,99.74,123.42a115.75,115.75,0,0,0,53-7c1.61-.6,4.51-.48,5.55.57C321.19,466.08,336.16,481.48,352.19,497.86Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-3" d="M259.52,235.83c14.83.18,29,2.89,42.38,8.92,6.13,2.77,11.65,6.9,17.38,10.51C354.93,277.72,369.79,311,368.5,352c-.43,13.8-3.32,27.41-10.79,39.5-1.64,2.66-.33,4.34,1.47,6,7.59,7,15.24,13.93,22.78,21,8.94,8.38,18,16.65,26.62,25.35,13,13.1,13,37.66.58,50.17-16,16.11-39.71,16-54,1.08-15.57-16.23-31.56-32.06-47.28-48.15-2.18-2.23-3.6-2.43-6.73-1A98.32,98.32,0,0,1,252,454.41c-25-1.94-47.17-11.18-65.8-28.17q-29.52-26.94-35-66.66c-2.05-14.73-1.39-29.38,3.2-43.46,2.81-8.6,7.06-16.8,11.37-24.81C185.77,253.92,218.74,238.18,259.52,235.83Zm74.75,109.92c0-41.77-33.56-74.92-75.46-75.17-43.6-.26-75,36.34-75.13,75.47-.15,42.12,33.35,75.3,75.65,75.23C301.1,421.21,334.32,387.73,334.27,345.75Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-1" d="M334.27,345.75c.05,42-33.17,75.46-74.94,75.53-42.3.07-75.8-33.11-75.65-75.23.15-39.13,31.53-75.73,75.13-75.47C300.71,270.83,334.23,304,334.27,345.75Zm-23.81-51.17C306.21,301,302,307,298.26,313.26a5.89,5.89,0,0,0,.08,5.24c7.05,10,9.43,21,8.85,33-1.21,25.15-26,50.24-57.27,44.86-27-4.64-44.41-28.79-41.21-54.87.19-1.58-.23-4.18-1.28-4.83-5.73-3.55-11.74-6.64-17.77-10-9.73,33.58,7.86,70.39,40,84.81A72.56,72.56,0,0,0,320.85,384C340.92,352,331.39,313.58,310.46,294.58ZM285.84,278.5c-24.8-13.2-67.88-1.62-82.65,22,5.81,3.19,11.73,6.18,17.36,9.64,2.33,1.43,3.62,1.13,5.61-.47,12.3-9.84,26.1-14,41.84-10.79,1.62.33,4.36-.28,5.21-1.45C277.65,291.33,281.66,284.88,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M310.46,294.58c20.93,19,30.46,57.41,10.39,89.43a72.56,72.56,0,0,1-91.19,27.52c-32.14-14.42-49.73-51.23-40-84.81,6,3.32,12,6.41,17.77,10,1,.65,1.47,3.25,1.27,4.83-3.19,26.08,14.25,50.23,41.22,54.87,31.26,5.38,56.06-19.71,57.27-44.86.58-12-1.8-23.06-8.85-33a5.89,5.89,0,0,1-.08-5.24C302,307,306.21,301,310.46,294.58Z" transform="translate(-1.03 -1.1)"/>
            <path class="cls-2" d="M285.84,278.5c-4.18,6.38-8.19,12.83-12.63,19-.85,1.17-3.58,1.78-5.21,1.45-15.74-3.18-29.54.95-41.84,10.79-2,1.6-3.28,1.9-5.61.47-5.63-3.46-11.55-6.45-17.36-9.64C218,276.88,261,265.3,285.84,278.5Z" transform="translate(-1.03 -1.1)"/>
         </svg>
      </div>
   ]])
end

function addLogoSvg()
   return ([[
      <div id='ntop-logo'>
      <svg
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:cc="http://creativecommons.org/ns#"
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:svg="http://www.w3.org/2000/svg"
      xmlns="http://www.w3.org/2000/svg"
      id="svg8"
      version="1.1"
      viewBox="0 0 13.758333 13.758334"
      height="52"
      width="52">
     <metadata
        id="metadata5">
       <rdf:RDF>
         <cc:Work
            rdf:about="">
           <dc:format>image/svg+xml</dc:format>
           <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage"></dc:type>
           <dc:title></dc:title>
         </cc:Work>
       </rdf:RDF>
     </metadata>
     <g
        id="layer1">
       <g
          style="font-style:normal;font-weight:normal;font-size:16.9333px;line-height:1.25;font-family:sans-serif;letter-spacing:0px;word-spacing:0px;fill:#ff7500;fill-opacity:1;stroke:none;stroke-width:0.264583"
          id="text835"
          aria-label="n">
         <path
            d="M 2.7739989,9.5828812 V 4.216811 q 0,-0.9839173 0.3224603,-1.4552054 0.3307285,-0.4795564 1.008722,-0.4795564 0.4051424,0 0.7193345,0.2149735 Q 5.1387078,2.7037281 5.378486,3.1336751 5.808433,2.662387 6.3706715,2.4474135 6.93291,2.2324399 7.7349267,2.2324399 q 1.5792286,0 2.4143183,0.9012352 0.835089,0.9012352 0.835089,2.6210235 v 3.8281826 q 0,0.9839178 -0.330728,1.4634738 -0.330729,0.479556 -1.0087222,0.479556 -0.6779934,0 -1.0087219,-0.479556 Q 8.3054333,10.566799 8.3054333,9.5828812 V 6.5649835 q 0,-1.1162088 -0.3389967,-1.5874969 -0.3307285,-0.4795563 -1.0996723,-0.4795563 -0.7276027,0 -1.0748677,0.4960927 -0.3472649,0.4878246 -0.3472649,1.5378876 v 3.0509706 q 0,0.9839178 -0.3307285,1.4634738 -0.3307286,0.479556 -1.008722,0.479556 -0.6779935,0 -1.008722,-0.479556 Q 2.7739989,10.566799 2.7739989,9.5828812 Z"
            style="font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;font-family:'VAGRounded BT';-inkscape-font-specification:'VAGRounded BT';fill:#ff7500;fill-opacity:1;stroke-width:0.264583"
            id="path873"></path>
       </g>
     </g>
   </svg>
      </div>
   ]])
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


--
-- Members supported format
-- 192.168.1.10/32@10
-- 00:11:22:33:44:55
--

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

-- This function actively resolves an host if there is not information about it.
-- NOTE: prefer the host2name on this function
function resolveAddress(hostinfo, allow_empty)
   local alt_name = ip2label(hostinfo["host"])

   if(not isEmptyString(alt_name) and (alt_name ~= hostinfo["host"])) then
      -- The host label has priority
      return(alt_name)
   end

   local hostname = ntop.resolveName(hostinfo["host"])
   if isEmptyString(hostname) then
      -- Not resolved
      if allow_empty == true then
         return hostname
      else
         -- this function will take care of formatting the IP
         return hostinfo2label(hostinfo)
      end
   end
   return hostinfo2label(hostinfo)
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

  if(findString(name, "Skype")) then icon = '<i class=\'fab fa-skype\'></i>'
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
  return(icon.." "..shortenString(name, 12))
end

-- #################################

function getCategoryLabel(cat_name)
  if isEmptyString(cat_name) then
   return("")
  end

  local v = i18n("ndpi_categories." .. cat_name)
  if v then
   -- Localized string found
   return(v)
  end

  cat_name = cat_name:gsub("^%l", string.upper)
  return(cat_name)
end

-- ###########################################

function computeL7Stats(stats, show_breed, show_ndpi_category)
   local _ifstats = {}

   if(show_breed) then
      local breed_stats = {}

      for key, value in pairs(stats["ndpi"]) do
         local b = stats["ndpi"][key]["breed"]

         local traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]

         if(breed_stats[b] == nil) then
            breed_stats[b] = traffic
         else
            breed_stats[b] = breed_stats[b] + traffic
         end
      end

      for key, value in pairs(breed_stats) do
         _ifstats[key] = value
      end

   elseif(show_ndpi_category) then
      local ndpi_category_stats = {}

      for key, value in pairs(stats["ndpi_categories"]) do
         key = getCategoryLabel(key)
         local traffic = value["bytes"]

         if(ndpi_category_stats[key] == nil) then
            ndpi_category_stats[key] = traffic
         else
            ndpi_category_stats[key] = ndpi_category_stats[key] + traffic
         end
      end

      for key, value in pairs(ndpi_category_stats) do
         _ifstats[key] = value
      end

   else
      -- Add ARP to stats
      local arpBytes = 0
      if(stats["eth"] ~= nil) then
         arpBytes = stats["eth"]["ARP_bytes"]
         if(arpBytes > 0) then
            _ifstats["ARP"] = arpBytes
         end
      end

      for key, value in pairs(stats["ndpi"]) do
         local traffic = value["bytes.sent"] + value["bytes.rcvd"]
         if(key == "Unknown") then
            traffic = traffic - arpBytes
         end

         if(traffic > 0) then
            if(show_breed) then
               _ifstats[value["breed"]] = traffic
            else
               _ifstats[key] = traffic
            end
         end
      end
   end

   return _ifstats
end

-- ###########################################

function getItemsNumber(n)
  tot = 0
  for k,v in pairs(n) do
    --io.write(k.."\n")
    tot = tot + 1
  end

  --io.write(tot.."\n")
  return(tot)
end

-- ###########################################

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

function getHostAltNamesKey(host_key)
   if(host_key == nil) then return(nil) end
   return "ntopng.cache.host_labels."..host_key
end

function getHostAltName(host_info)
   local host_key

   if type(host_info) == "table" then
     host_key = host_info["host"]
   else
     host_key = host_info
   end

   local alt_name = ntop.getCache(getHostAltNamesKey(host_key))

   if isEmptyString(alt_name) and type(host_info) == "table" and host_info["vlan"] then
      -- Check if there is an alias for the host@vlan
      host_key = hostinfo2hostkey(host_info)
      alt_name = ntop.getCache(getHostAltNamesKey(host_key))
   end

   return alt_name
end

function setHostAltName(host_info, alt_name)
   local host_key

   if type(host_info) == "table" then
     -- Note: we are not using hostinfo2hostkey which includes the
     -- vlan for backward compatibility, compatibility with
     -- the backend, and compatibility with the vpn plugins
     host_key = host_info["host"] -- hostinfo2hostkey(host_info)
   else
     host_key = host_info
   end

   ntop.setCache(getHostAltNamesKey(host_key), alt_name)
end

-- ##############################################

function getDhcpNameKey(ifid, mac)
   return string.format("ntopng.dhcp.%d.cache.%s", ifid, mac)
end

-- ##############################################

local function label2formattedlabel(alt_name, host_info, show_vlan, shorten_len)
   if not isEmptyString(alt_name) then
      local ip = host_info["ip"] or host_info["host"]
      -- Make it shorter
      local res = alt_name

      -- Special shorting function for IP addresses
      if res ~= ip then
         if shorten_len then
            res = shortenString(res, shorten_len)
         else
            res = shortenString(res)
         end
      end

      -- Adding the vlan if requested
      if show_vlan then
	 local vlan = tonumber(host_info["vlan"])

	 if vlan and vlan > 0 then
	    local full_vlan_name = getFullVlanName(vlan, true --[[ Compact --]])

	    res = string.format("%s@%s", res, full_vlan_name)
	 end
      end

      return res
   end

   -- Fallback: just the IP and VLAN
   return(hostinfo2hostkey(host_info, true))
end

-- ##############################################

-- Attempt at retrieving an host label from an host_info, using local caches and DNS resolution.
-- This can be more expensive if compared to only using information found inside host_info.
local function hostinfo2label_resolved(host_info, show_vlan, shorten_len)
   local ip = host_info["ip"] or host_info["host"]
   local res

   -- If local broadcast domain host and DHCP, try to get the label associated
   -- to the MAC address
   if host_info["mac"] and (host_info["broadcast_domain_host"] or host_info["dhcpHost"]) then
      res = getHostAltName(host_info["mac"])
   end

   if isEmptyString(res) then
      -- Try and get the resolved name
      res = ntop.getResolvedName(ip)

      if isEmptyString(res) then
	 -- Nothing found, just fallback to the IP address
	 res = ip
      end
   end

   return label2formattedlabel(res, host_info, show_vlan, shorten_len)
end

-- ##############################################

-- Retrieve an host label from an host_info. The minimum fields of
-- the host_info are "host" and "vlan", however a full JSON from Host::lua
-- is needed to provide an accurate result.
--
-- The following order is used to determine the label:
--    MAC label (LBD hosts only), IP label, MDNS/DHCP name from C, resolved IP
--
-- NOTE: The function attempt at labelling an host only using information found in host_info.
-- In case host_info is not enough to label the host, then local caches and DNS resolution kick in
-- to find a label (at the expense of extra time).
function hostinfo2label(host_info, show_vlan, shorten_len)
   local alt_name = nil
   local ip = host_info["ip"] or host_info["host"]

   -- Take the label as found in the host structure
   local res = host_info.label

   if isEmptyString(res) then
      -- Use any user-configured custom name
      -- This goes first as a label set by the user MUST take precedance over any other possibly available label
      res = getHostAltName(ip)

      if isEmptyString(res) then
	 -- Read what is found inside host `name`, e.g., name as found by dissected traffic such as DHCP
	 res = host_info["name"]

	 if isEmptyString(res) then
	    return hostinfo2label_resolved(host_info, show_vlan, shorten_len)
	 end
      end
   end
   return label2formattedlabel(res, host_info, show_vlan, shorten_len)
end

-- ##############################################

-- Just a convenience function for hostinfo2label with only IP and VLAN
function ip2label(ip, vlan)
   return hostinfo2label({host = ip, vlan = (vlan or 0)})
end

-- ##############################################

function mac2label(mac)
   local alt_name = getHostAltName(mac)

   if not isEmptyString(alt_name) and (alt_name ~= mac) then
      return(alt_name)
   end

   alt_name = ntop.getCache(getDhcpNameKey(interface.getId(), mac))

   if not isEmptyString(alt_name) and (alt_name ~= mac) then
      return(alt_name)
   end

   -- Fallback: just the MAC
   return(mac)
end

-- ##############################################

-- Mac Addresses --

-- A function to give a useful device name
function getDeviceName(device_mac, skip_manufacturer)
   local name = mac2label(device_mac)

   if name == device_mac then
      -- Not found, try with first host
      local info = interface.getHostsInfo(false, nil, 1, 0, nil, nil, nil, tonumber(vlan), nil,
               nil, device_mac)

      if (info ~= nil) then
         for x, host in pairs(info.hosts) do
            if not isEmptyString(host.name) and host.name ~= host.ip and host.name ~= "NoIP" then
               name = host.name
            elseif host.ip ~= "0.0.0.0" then
               name = ip2label(host.ip)
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

-- ##############################################

-- @brief Implements the logic to decide whether to show or not the url for a given `host_info`
local function hostdetails_exists(host_info, hostdetails_params)
   if not hostdetails_params then
      hostdetails_params = {}
   end

   if hostdetails_params["page"] ~= "historical" and not hostdetails_params["ts_schema"] then
      -- If the requested host_details.lua page is not the "historical" page
      -- and if no ts_schema has been requested
      -- then we check for host existance in memory, to make sure the page host_details.lua
      -- won't bring to an empty page.
      if not host_info["ipkey"] then
	 -- host_info hasn't been generated with Host::lua so we can try and
	 -- see if the host is active
	 local active_host = interface.getHostInfo(hostinfo2hostkey(host_info))
	 if not active_host then
	    return false
	 end
      end
   else
      -- If the requested page is the "historical" page, or if a ts_schema has been requested,
      -- then we assume page host_details.lua
      -- exists if the timeseries are enabled and if the requested timeseries exists for the host
      if not hostdetails_params["ts_schema"] then
	 -- Default schema for hosts
	 hostdetails_params["ts_schema"] = "host:traffic"
      end

      -- A ts_schema has been requested, let's see if it exists
      local ts_utils = require("ts_utils_core")
      local tags = table.merge(host_info, hostdetails_params)
      if not tags["ifid"] then tags["ifid"] = interface.getId() end

      -- If nIndex support is enabled, then there's no need to check for existence of the
      -- schema: nIndex flows must be visible from the historical page even when there's no timeseries
      -- associated
      if not interfaceHasNindexSupport() and not ts_utils.exists(hostdetails_params["ts_schema"], tags) then
	 -- If here, the requested schema, along with its hostdetails_params doesn't exist
	 return false
      end
   end
   return true
end

-- ##############################################

-- @brief Generates an host_details.lua url (if available)
-- @param host_info A lua table containing at least keys `host` and `vlan` or a full lua table generated with Host::lua
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @return A string containing the url (if available) or an empty string when the url is not available
function hostinfo2detailsurl(host_info, href_params, href_check)
   local res = ''

   if not href_check or hostdetails_exists(host_info, href_params) then
      local auth = require "auth"
      local url_params = table.tconcat(href_params or {}, "=", "&")

      -- Alerts pages for the host are in alert_stats.lua (Alerts menu)
      if href_params and href_params.page == "engaged-alerts" then
	 if auth.has_capability(auth.capabilities.alerts) then
	    res = string.format("%s/lua/alert_stats.lua?page=host&status=engaged&ip=%s%s%s",
				ntop.getHttpPrefix(),
				hostinfo2hostkey(host_info),
                                tag_utils.SEPARATOR, "eq")
	 end
      elseif href_params and href_params.page == "alerts" then
	 if auth.has_capability(auth.capabilities.alerts) then
	    res = string.format("%s/lua/alert_stats.lua?page=host&status=historical&ip=%s%s%s",
				ntop.getHttpPrefix(),
				hostinfo2hostkey(host_info),
                                tag_utils.SEPARATOR, "eq")
	 end
      -- All other pages are in host_details.lua
      else
         res = string.format("%s/lua/host_details.lua?%s%s%s",
			  ntop.getHttpPrefix(),
			  hostinfo2url(host_info),
			  isEmptyString(url_params) and '' or '&',
			  url_params,
			  href_value)
      end
   end

   return res
end

-- ##############################################

-- @brief Generates an host_details.lua a href link (if available), starting from an `host_info` structure
-- @param host_info A lua table containing at least keys `host` and `vlan` or a full lua table generated with Host::lua
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_value A string containing the visible value shown between a href tags
-- @param href_tooltip A string containing a tooltip shown when hovering the mouse on the link
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @param href_only_with_ts True means that a HREF is geneated only of there are timeseries for this host
-- @return A string containing the a href link or a plain string without a href
function hostinfo2detailshref(host_info, href_params, href_value, href_tooltip, href_check, href_only_with_ts)
   local show_href = false

   if(href_only_with_ts == true) then
      local detailLevel = ntop.getCache("ntopng.prefs.hosts_ts_creation")

      if(detailLevel == "full") then
	 local l7 = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")

	 if(l7 ~= "none") then
	    show_href = true
	 end
      end
   else
      show_href = true
   end

   if(show_href) then
      local hostdetails_url = hostinfo2detailsurl(host_info, href_params, href_check)

      if not isEmptyString(hostdetails_url) then
	 res = string.format("<a href='%s' data-bs-toggle='tooltip' title='%s'>%s</a>",
			     hostdetails_url, href_tooltip or '', href_value or '')
      else
	 res = href_value or ''
      end

      return res
   else
      return(href_value)
   end
end

-- ##############################################

-- @brief Generates an host_details.lua a href link (if available), starting from an ip and a vlan
-- @param ip A string with a valid ip address
-- @param vlan A string or a number with a VLAN or nil when VLAN information is not available
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_value A string containing the visible value shown between a href tags
-- @param href_tooltip A string containing a tooltip shown when hovering the mouse on the link
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @return A string containing the a href link or a plain string without a href
function ip2detailshref(ip, vlan, href_params, href_value, href_tooltip, href_check)
   return hostinfo2detailshref({host = ip, vlan = tonumber(vlan) or 0}, href_params, href_value, href_tooltip, href_check)
end

-- ##############################################

-- Flow Utils --

function flowinfo2hostname(flow_info, host_type, alerts_view)
   local name
   local orig_name

   if alerts_view and not hasNindexSupport() then
      -- do not return resolved name as it will hide the IP address
      return(flow_info[host_type..".ip"])
   end

   if(flow_info == nil) then return("") end
   
   if(host_type == "srv") then
      if flow_info["host_server_name"] ~= nil and flow_info["host_server_name"] ~= "" and flow_info["host_server_name"]:match("%w") then
	 -- remove possible ports from the name
	 return(flow_info["host_server_name"]:gsub(":%d+$", ""))
      end
      if(flow_info["protos.tls.certificate"] ~= nil and flow_info["protos.tls.certificate"] ~= "") then
	 return(flow_info["protos.tls.certificate"])
      end
   end

   local hostinfo = {
      host = flow_info[host_type..".ip"],
      label = flow_info[host_type..".host"],
      mac = flow_info[host_type..".mac"],
      dhcpHost = flow_info[host_type..".dhcpHost"],
      broadcast_domain_host = flow_info[host_type..".broadcast_domain_host"],
      vlan = flow_info["vlan"],
   }

   return(hostinfo2label(hostinfo))
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
   local alias = ntop.getLocalNetworkAlias(network) or nil

   if not alias then
      alias = ntop.getHashCache(getLocalNetworkAliasKey(), network)      
   end

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

function getVlanAliasKey()
   return "ntopng.vlan_aliases"
end

-- ##############################################

function getVlanAlias(vlan_id)
   local alias = ntop.getHashCache(getVlanAliasKey(), vlan_id)

   if not isEmptyString(alias) then
      return alias
   end

   return tostring(vlan_id)
end

-- ##############################################

function setVlanAlias(vlan_id, alias)
   if((vlan_id ~= alias) or isEmptyString(alias)) then
      ntop.setHashCache(getVlanAliasKey(), vlan_id, alias)
   else
      ntop.delHashCache(getVlanAliasKey(), vlan_id)
   end
end

-- ##############################################

function getFullVlanName(vlan_id, compact)
   local alias = getVlanAlias(vlan_id)

   if not isEmptyString(alias) then
      if not isEmptyString(alias) and alias ~= tostring(vlan_id) then
	 if compact then
	    alias = shortenString(alias)
	    return string.format("%s", alias)
	 else
	    return string.format("%u [%s]", vlan_id, alias)
	 end
      end
   end

   return vlan_id
end

-- ##############################################

function flow2hostinfo(host_info, host_type)
   if host_type == "cli" then
      return({host = host_info["cli.ip"], vlan = host_info["cli.vlan"]})
   elseif host_type == "srv" then
      return({host = host_info["srv.ip"], vlan = host_info["srv.vlan"]})
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
function hostinfo2hostkey(host_info, host_type, show_vlan)
   local rsp = ""

   if(host_type == "cli") then
      local cli_ip = host_info["cli.ip"] or host_info["cli_ip"]

      if cli_ip then
	 rsp = rsp..cli_ip
      end

   elseif(host_type == "srv") then
      local srv_ip = host_info["srv.ip"] or host_info["srv_ip"]

      if srv_ip then
	 rsp = rsp..srv_ip
      end
   else

      if(host_info["ip"] ~= nil) then
	 rsp = rsp..host_info["ip"]
      elseif(host_info["mac"] ~= nil) then
	 rsp = rsp..host_info["mac"]
      elseif(host_info["host"] ~= nil) then
	 rsp = rsp..host_info["host"]
      elseif(host_info["name"] ~= nil) then
	 rsp = rsp..host_info["name"]
      end
   end

   local vlan_id = tonumber(host_info["vlan"] or host_info["vlan_id"] or 0)

   if vlan_id ~= 0 or show_vlan then
      rsp = rsp..'@'..tostring(vlan_id)
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
	 rsp = rsp..'host='..hostinfo2hostkey(flow2hostinfo(host_info, "cli"))
      end

   elseif(host_type == "srv") then
      if(host_info["srv.ip"] ~= nil) then
	 rsp = rsp..'host='..hostinfo2hostkey(flow2hostinfo(host_info, "srv"))
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

-----  End of Redis Utils  ------


function isPausedInterface(current_ifname)
   if(not isEmptyString(_POST["toggle_local"])) then
      return(_POST["toggle_local"] == "0")
   end

  state = ntop.getCache("ntopng.prefs.ifid_"..tostring(interface.name2id(current_ifname)).."_not_idle")
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
   local ifspeed = ntop.getCache('ntopng.prefs.ifid_'..tostring(ifid)..'.speed')
   if not isEmptyString(ifspeed) and tonumber(ifspeed) ~= nil then
      ifspeed = tonumber(ifspeed)
   else
      ifspeed = interface.getMaxIfSpeed(ifid)
   end

   return ifspeed
end

function getInterfaceRefreshRate(ifid)
   local key = "ntopng.prefs.ifid_"..tostring(ifid)..".refresh_rate"
   local refreshrate = ntop.getCache(key)

   if isEmptyString(refreshrate) or tonumber(refreshrate) == nil then
      refreshrate = 3
   else
      refreshrate = tonumber(refreshrate)
   end

   return refreshrate
end

function setInterfaceRegreshRate(ifid, refreshrate)
   local key = "ntopng.prefs.ifid_"..tostring(ifid)..".refresh_rate"

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

-- ##############################################

function getHumanReadableInterfaceName(interface_name)
   local interface_id = nil

   if(interface_name == "__system__") then
      return(i18n("system"))
   elseif tonumber(interface_name) ~= nil then
      -- convert ID to name
      interface_id = tonumber(interface_name)
      interface_name = getInterfaceName(interface_name)
   else
      -- Parameter is a string, let's take it's id first
      interface_id = getInterfaceId(interface_name)
      -- and then get the name
      interface_name = getInterfaceName(interface_id)
   end

   local key = 'ntopng.prefs.ifid_'..tostring(interface_id)..'.name'
   local custom_name = ntop.getCache(key)

   if not isEmptyString(custom_name) then
      return(shortenCollapse(custom_name))
   end

   return interface_name
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

function unescapeHttpHost(host)
   if isEmptyString(host) then
      return(host)
   end

   return string.gsub(string.gsub(host, "http:__", "http://"), "https:__", "https://")
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

function isAdministratorOrPrintErr(isJsonResponse)

   if (isAdministrator()) then
      return(true)
   end

   local isJson = isJsonResponse or false

   if (isJson) then
      local json = require("dkjson")
      sendHTTPContentTypeHeader('application/json')
      print(json.encode({}))
   else
      local page_utils = require("page_utils")
      page_utils.print_header()
      dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
      print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> Access forbidden</div>")
   end

   return(false)
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
      return("<i class='fas fa-thumbs-down' style='color: red'></i>")
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
      return(" <a href='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country=".. country .."'><img src='".. ntop.getHttpPrefix() .. "/img/blank.gif' class='flag flag-".. string.lower(country) .."'></a> ")
   end
end

-- GENERIC UTILS

-- split
function split(s, delimiter)
   result = {};
   if(s ~= nil) then
      if delimiter == nil then
         -- No delimiter, split all characters
         for match in s:gmatch"." do
   	    table.insert(result, match);
         end
      else
         -- Split by delimiter
         for match in (s..delimiter):gmatch("(.-)"..delimiter) do
   	    table.insert(result, match);
         end
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
   ["00:00:00:00:00:00"] = "",
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

function macInfoWithSymbName(mac, name)
   return(' <A HREF="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='.. mac ..'">'..name..'</A> ')
end

function macInfo(mac)
  return(' <A HREF="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='.. mac ..'">'..mac..'</A> ')
end

-- get_symbolic_mac
function get_symbolic_mac(mac_address, no_href, add_extra_info) 
   if(magic_macs[mac_address] ~= nil) then
      return(magic_macs[mac_address])
   else
      local m = string.sub(mac_address, 1, 8)
      local t = string.sub(mac_address, 10, 17)

      if(magic_short_macs[m] ~= nil) then
	 if(add_extra_info == true) then
	    return(magic_short_macs[m].."_"..t.." ("..macInfo(mac_address)..")")
	 else
	    if no_href then
	       return(magic_short_macs[m].."_"..t)
	    else
	       return(macInfoWithSymbName(mac_address, magic_short_macs[m].."_"..t))
	    end
	 end
      else
	 local s = get_mac_classification(m)

	 if(m == s) then
	    if no_href then
	       return  get_mac_classification(m) .. ":" .. t
	    else
	       return '<a href="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?host='..mac_address..'">' .. get_mac_classification(m) .. ":" .. t .. '</a>'
	    end
	 else
	    if(add_extra_info == true) then
	       return(get_mac_classification(m).."_"..t.." ("..macInfo(mac_address)..")")
	    else
	       return(get_mac_classification(m).."_"..t)
	    end
	 end
      end
   end
end

function get_mac_url(mac)
   local m = get_symbolic_mac(mac, true)

   if isEmptyString(m) then
      return ""
   end

   local url = ntop.getHttpPrefix() .."/lua/mac_details.lua?host="..mac

   return string.format('[ <a href=\"%s\">%s</a> ]', url, m)
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

-- prints purged information for hosts / flows
function purgedErrorString()
    local info = ntop.getInfo(false)
    return i18n("purged_error_message",{url=ntop.getHttpPrefix()..'/lua/admin/prefs.lua?tab=in_memory', product=info["product"]})
end

-- print TCP flags
function printTCPFlags(flags)
   if(hasbit(flags,0x01)) then print('<span class="badge bg-warning">FIN</span> ') end
   if(hasbit(flags,0x02)) then print('<span class="badge bg-warning">SYN</span> ')  end
   if(hasbit(flags,0x04)) then print('<span class="badge bg-danger">RST</span> ') end
   if(hasbit(flags,0x08)) then print('<span class="badge bg-warning">PUSH</span> ') end
   if(hasbit(flags,0x10)) then print('<span class="badge bg-warning">ACK</span> ')  end
   if(hasbit(flags,0x20)) then print('<span class="badge bg-warning">URG</span> ')  end
   if(hasbit(flags,0x40)) then print('<span class="badge bg-warning">ECE</span> ')  end
   if(hasbit(flags,0x80)) then print('<span class="badge bg-warning">CWR</span> ')  end
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
      -- print('<span class="badge bg-info">')
      print('<a href="'..hist_url..'&epoch_begin='..tostring(ago1h)..'" title="'..i18n("db_explorer.last_hour_flows")..'"><i class="fas fa-history fa-lg"></i></a>')
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

-- @brief The difference, in seconds, between the local time of this instance and GMT
local server_timezone_diff_seconds

-- @brief Compute and return the difference, in seconds, between the local time of this instance and GMT
-- @return A positive or negative number corresponding to the seconds between local time and GMT
local function get_server_timezone_diff_seconds()
   if not server_timezone_diff_seconds then
      local tmp_time = os.time()
      local d1 = os.date("*t",  tmp_time)
      local d2 = os.date("!*t", tmp_time)
      -- Forcefully set isdst to false otherwise difference won't work during DST
      d1.isdst = false
      -- Use a minus to have the difference between local time and GMT, rather than between GMT and loca ltime
      server_timezone_diff_seconds = -os.difftime(os.time(d1), os.time(d2))
   end

   return server_timezone_diff_seconds
end

-- ####################################################

-- @brief Get the frontend timezone offset in seconds
-- @return The offset of the frontend timezone
function getFrontendTzSeconds()
  local frontend_tz_offset = nil

  if _COOKIE and _COOKIE.tzoffset then
    -- The timezone offset can be passed from the client as a cookie.
    -- This allows to format the dates in the frontend timezone.
    frontend_tz_offset = tonumber(_COOKIE.tzoffset)
  end

  if frontend_tz_offset == nil then
     -- If timezone is not available in the client _COOKIE,
     -- server timezone is used as fallback
     return -get_server_timezone_diff_seconds()
  end

   return frontend_tz_offset
end

-- ####################################################

-- @brief Converts a datetime string into an epoch, adjusted with the client time
function makeTimeStamp(d)
   local pattern = "(%d+)%/(%d+)%/(%d+) (%d+):(%d+):(%d+)"
   local day, month, year, hour, minute, seconds = string.match(d, pattern);

   -- Get the epoch out of d. The epoch gets adjusted by os.time in the server timezone, that is, in
   -- the timezone of this running ntopng instance
   -- See https://www.lua.org/pil/22.1.html
   local server_epoch = os.time({year = year, month = month, day = day, hour = hour, min = minute, sec = seconds});

   -- Convert the server_epoch into a gmt_epoch which is adjusted to GMT
   local gmt_epoch = server_epoch + get_server_timezone_diff_seconds()

   -- Finally, compute a client_epoch by adding the seconds of getFrontendTzSeconds() to the GMT epoch just computed
   local client_epoch = gmt_epoch + getFrontendTzSeconds()

   -- Now we can compute the deltas to know the extact number of seconds between the server and the client timezone
   local server_to_gmt_delta = gmt_epoch - server_epoch
   local gmt_to_client_delta = client_epoch - gmt_epoch
   local server_to_client_delta = client_epoch - server_epoch

   -- Make sure everything is OK...
   assert(server_to_client_delta == server_to_gmt_delta + gmt_to_client_delta)

   -- tprint({
   --    server_ts = server_epoch,
   --    gmt_ts = gmt_epoch,
   --    server_to_gmt_delta = (server_to_gmt_delta) / 60 / 60,
   --    gmt_to_client_delta = (gmt_to_client_delta) / 60 / 60,
   --    server_to_client_delta = (server_to_client_delta) / 60 / 60
   -- })

   -- Return the epoch in the client timezone
   return string.format("%u", server_epoch - server_to_client_delta)
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
  html_lines[#html_lines+1] = [[<div class="btn-group ]] .. table.concat(extra.classes or {}, "") .. [[" id="]] .. ctrl_id .. [[" role="group" style="]] .. table.tconcat(style, ":", "; ", ";") .. [[">]]

  -- foreach character in format
  string.gsub(fmt, ".", function(k)

    local v = fmt_to_data[k]
    if v ~= nil then
         local line = {}

         if((max_val == nil) or (v.value < max_val)) then

            local input_name = ("opt_resbt_%s_%s"):format(k, ctrl_id)
            local input = ([[
               <input class="btn-check" data-resol="%s" value="%s" title="%s" name="%s" id="input-%s" autocomplete="off" type="radio" %s/>
                  ]]):format(k, truncate(v.value), v.label, input_name, input_name, ternary((selected == k), 'checked="checked"', ""))
            local label = ([[
               <label class="btn btn-sm %s" for="input-%s">%s</label>
            ]]):format(ternary((selected == k), "btn-primary", "btn-secondary"), input_name, v.label)

	    line[#line+1] = input
            line[#line+1] = label

            html_lines[#html_lines+1] = table.concat(line, "")
       end
    end
	       end)

  html_lines[#html_lines+1] = [[</div>]]

  -- Note: no // comment below, only /* */

  local js_init_code = [[
      var _resol_inputs = [];

      function resol_selector_get_input(a_button) {
        return $("input", $(a_button).closest(".form-group.mb-3")).last();
      }

      function resol_selector_get_buttons(an_input) {
        return $(".btn-group", $(an_input).closest(".form-group.mb-3")).first().find("input");
      }

      /* This function scales values wrt selected resolution */
      function resol_selector_reset_input_range($selected) {
        let duration = $($selected);
        let input = resol_selector_get_input(duration);

        let raw = parseInt(input.attr("data-min"));
        if (! isNaN(raw))
          input.attr("min", Math.sign(raw) * Math.ceil(Math.abs(raw) / duration.val()));

        raw = parseInt(input.attr("data-max"));
        if (! isNaN(raw))
          input.attr("max", Math.sign(raw) * Math.ceil(Math.abs(raw) / duration.val()));

        var step = parseInt(input.attr("data-step-" + duration.attr("data-resol")));
        if (! isNaN(step)) {
          input.attr("step", step);

          /* Align value */
          input.val(input.val() - input.val() % step);
        } else
          input.attr("step", "");

        resol_recheck_input_range(input);
      }

      /* 
       * Remove the checked value inside the radio buttons
       * and add it only to the one selected 
       */
      function resol_selector_change_callback(event) {
        $(this).parent().find('label').removeClass('btn-primary').addClass('btn-secondary');
        $(this).parent().find('input[type="radio"]').prop('checked', false);
        $(this).prop('checked', true).removeClass('btn-secondary').addClass('btn-primary');
        $(this).parent().find('label[for="' + $(this).attr('id') + '"]').removeClass('btn-secondary').addClass('btn-primary');
 
        resol_selector_reset_input_range($(this));
      }

      /* Function used to check the value input range */
      function resol_recheck_input_range(input) {
        let value = input.val();

        if (input[0].hasAttribute("min") && Number.isNaN(input.attr("min")))
          value = Math.max(parseInt(input.val()), !input.attr("min"));
        if (input[0].hasAttribute("max") && Number.isNaN(input.attr("max")))
          value = Math.min(parseInt(input.val()), !input.attr("max"));

        if ((input.val() != "") && (input.val() != value))
          input.val(value);
      }


      function resol_selector_on_form_submit(event) {
        var form = $(this);

        if (event.isDefaultPrevented() || (form.find(".has-error").length > 0))
          return false;

        resol_selector_finalize(form);
        return true;
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
  local html = string.gsub(table.concat(html_lines, " "), "\n", "")
  js_init_code = string.gsub(js_init_code, "", "")
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
  if (not ntop.isEnterpriseM()) or (not isAdministrator()) then
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
  if((key ~= nil) and (#key == 2)) then
     -- Verify that the host is actually an IP address and the VLAN actually
     -- a number to avoid stripping things that are not vlans (e.g. part of an host name)
     local addr = key[1]

     if((tonumber(key[2]) ~= nil) and (isIPv6(addr) or isIPv4(addr))) then
      return(addr)
     end
  end

  return(name)
end

function getSafeChildIcon()
   return("&nbsp;<font color='#5cb85c'><i class='fas fa-lg fa-child' aria-hidden='true'></i></font>")
end

-- ###########################################

function getNtopngRelease(ntopng_info)
   local release

   if ntopng_info.oem or ntopng_info["version.nedge_edition"] then
      release = ""
   elseif(ntopng_info["version.enterprise_l_edition"]) then
      release =  "Enterprise L"
   elseif(ntopng_info["version.enterprise_m_edition"]) then
      release =  "Enterprise M"
   elseif(ntopng_info["version.enterprise_edition"]) or (ntopng_info["version.nedge_enterprise_edition"]) then
      release =  "Enterprise"
   elseif(ntopng_info["pro.release"]) then
      release =  "Professional"
   elseif(ntopng_info["version.embedded_edition"]) then
      release = "/Embedded"
   else
      release =  "Community"
   end

   -- E.g., ntopng edge v.4.3.210112 (Ubuntu 16.04.6 LTS)
   local res = string.format("%s %s v.%s (%s)", ntopng_info.product, release, ntopng_info.version, ntopng_info.OS)

   if not ntopng_info.oem then
      local vers = string.split(ntopng_info["version.git"], ":")

      if vers and vers[2] then
	 local ntopng_git_url = "<A HREF=\"https://github.com/ntop/ntopng/commit/".. vers[2] .."\"><i class='fab fa-github'></i></A>"

	 res = string.format("%s | %s", res, ntopng_git_url)
      end
   end

   return res
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

function getGwMacsSet(ifid)
   return "ntopng.prefs.iface_" .. ifid .. ".gw_macs"
end

-- ###########################################

function printWarningAlert(message)
   print[[<div class="alert alert-warning alert-dismissable" role="alert">]]
   print[[<i class="fas fa-exclamation-triangle fa-sm"></i> ]]
   print[[<strong>]] print(i18n("warning")) print[[</strong> ]]
   print(message)
   print[[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
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
    ]])

      if (msg.type == "warning") then
         print("<b>".. i18n("warning") .. "</b>: ")
      elseif (msg.type == "danger") then
         print("<b>".. i18n("error") .. "</b>: ")
      end

      print(msg.text)

      print[[
         <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
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
--! @param path the path to compute the size for
--! @param timeout the maxium time to compute the size. If nil, it defaults to 15 seconds.
function getFolderSize(path, timeout)
   local folder_size_key = "ntopng.cache.folder_size"
   local now = os.time()
   local expiration = 30 -- sec
   local size = nil

   if ntop.isWindows() then
      size = 0 -- TODO
   else
      local MAX_TIMEOUT = tonumber(timeout) or 15 -- default
      -- Check if timeout is present on the system to cap the execution time of the subsequent du,
      -- which may be very time consuming, especially when the number of files is high
      local has_timeout = ntop.getCache("ntopng.cache.has_gnu_timeout")

      if isEmptyString(has_timeout) then
	 -- Cache the timeout
	 -- Check timeout existence with which. If no timeout is found, command will return nil
	 has_timeout = (os_utils.execWithOutput("which timeout >/dev/null 2>&1") ~= nil)
	 ntop.setCache("ntopng.cache.has_gnu_timeout", tostring(has_timeout), 3600)
      else
	 has_timeout = has_timeout == "true"
      end

      -- Check the cache for a recent value
      local time_size = ntop.getHashCache(folder_size_key, path)
      if not isEmptyString(time_size) then
         local values = split(time_size, ',')
         if #values >= 2 and tonumber(values[1]) >= (now - expiration) then
            size = tonumber(values[2])
         end
      end

      if size == nil then
         size = 0
         -- Read disk utilization
	 local periodic_activities_utils = require "periodic_activities_utils"
         if ntop.isdir(path) and not periodic_activities_utils.have_degraded_performance() then
	    local du_cmd = string.format("du -s %s 2>/dev/null", path)
	    if has_timeout then
	       du_cmd = string.format("timeout %u%s %s", MAX_TIMEOUT, "s", du_cmd)
	    end

	    -- use POSIXLY_CORRECT=1 to guarantee results is returned in 512-byte blocks
	    -- both on BSD and Linux
            local line = os_utils.execWithOutput(string.format("POSIXLY_CORRECT=1 %s", du_cmd))
            local values = split(line, '\t')
            if #values >= 1 then
               local used = tonumber(values[1])
               if used ~= nil then
                  size = math.ceil(used * 512)

                  -- Cache disk utilization
                  ntop.setHashCache("ntopng.cache.folder_size", path, now..","..size)
               end
            end
         end
      end
   end

   return size
end

-- ##############################################

--- Return an HTML `select` element with passed options.
--
function generate_select(id, name, is_required, is_disabled, options, additional_classes)
   local required_flag = (is_required and "required" or "")
   local disabled_flag = (is_disabled and "disabled" or "")
   local name_attr = (name ~= "" and "name='" .. name .. "'" or "")
   local parsed_options = ""
   for i, option in ipairs(options) do
      parsed_options = parsed_options .. ([[
         <option ]].. (i == 1 and "selected" or "") ..[[ value="]].. option.value ..[[">]].. option.title ..[[</option>
      ]])
   end

   return ([[
      <select id="]].. id ..[[" class="form-select ]] .. (additional_classes or "") .. [[" ]].. name_attr ..[[ ]].. required_flag ..[[ ]] .. disabled_flag ..[[>
         ]].. parsed_options ..[[
      </select>
   ]])
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

-- NOTE: '~= "0"' is used for prefs which are enabled by default
function areInterfaceTimeseriesEnabled(ifid)
   return((ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0"))
end

function areInterfaceL7TimeseriesEnabled(ifid)
   return(areInterfaceTimeseriesEnabled(ifid) and
      (ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation") ~= "per_category"))
end

function areInterfaceCategoriesTimeseriesEnabled(ifid)
   local rv = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")

   -- note: categories are disabled by default
   return(areInterfaceTimeseriesEnabled(ifid) and
      ((rv == "per_category") or (rv == "both")))
end

function areHostTimeseriesEnabled(ifid)
   local rv = ntop.getPref("ntopng.prefs.hosts_ts_creation")
   if isEmptyString(rv) then rv = "light" end

   return((rv == "light") or (rv == "full"))
end

function areHostL7TimeseriesEnabled(ifid)
   local rv = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

   -- note: host protocols are disabled by default
   return((ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and
      ((rv == "per_protocol") or (rv == "both")))
end

function areHostCategoriesTimeseriesEnabled(ifid)
   local rv = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

   -- note: host protocols are disabled by default
   return((ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and
      ((rv == "per_category") or (rv == "both")))
end

function areSystemTimeseriesEnabled()
   return(ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0")
end

function areHostPoolsTimeseriesEnabled(ifid)
   return(ntop.isPro() and (ntop.getPref("ntopng.prefs.host_pools_rrd_creation") == "1"))
end

function areASTimeseriesEnabled(ifid)
   return(ntop.getPref("ntopng.prefs.asn_rrd_creation") == "1")
end

function areInternalTimeseriesEnabled(ifid)
   -- NOTE: no separate preference so far
   return(areSystemTimeseriesEnabled())
end

function areCountryTimeseriesEnabled(ifid)
   return((ntop.getPref("ntopng.prefs.country_rrd_creation") == "1"))
end

function areOSTimeseriesEnabled(ifid)
   return((ntop.getPref("ntopng.prefs.os_rrd_creation") == "1"))
end

function areVlanTimeseriesEnabled(ifid)
   return(ntop.getPref("ntopng.prefs.vlan_rrd_creation") == "1")
end

function areMacsTimeseriesEnabled(ifid)
   return(ntop.getPref("ntopng.prefs.l2_device_rrd_creation") == "1")
end

function areContainersTimeseriesEnabled(ifid)
   -- NOTE: no separate preference so far
   return(true)
end

function areSnmpTimeseriesEnabled(device, port_idx)
   return(ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation") == "1")
end

function areFlowdevTimeseriesEnabled(ifid, device)
   return(ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation") == "1")
end

-- ###########################################

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

  local version_elems = split(info["version"], " ")
  local new_version = version2int(latest_version)
  local this_version = version2int(version_elems[1])

  if (new_version > this_version) then
      return i18n("about.new_major_available", {
         product = info["product"], version = latest_version,
         url = "http://www.ntop.org/get-started/download/"
      })
   end

   return ""

end

--- Check if there is a new major release
--- @return string message If there is a new major release then return a non-nil string
--- containing the update message.
function check_latest_major_release()

   if ntop.isOffline() then
      return nil
   end

   -- get the latest major release
   local latest_version = ntop.getCache("ntopng.cache.major_release")

   -- tprint(debug.traceback())

   if isEmptyString(latest_version) then
     local rsp = ntop.httpGet("https://www.ntop.org/ntopng.version", "", "", 10 --[[ seconds ]])

     if (not isEmptyString(rsp)) and (not isEmptyString(rsp["CONTENT"])) then
        latest_version = trimSpace(string.gsub(rsp["CONTENT"], "\n", ""))
     else
        -- a value that won't trigger an update message
        latest_version = "0.0.0"
     end

     ntop.setCache("ntopng.cache.major_release", latest_version, 86400 --[[ recheck interval]])
   end

   return get_version_update_msg(info, latest_version)
end

-- ###########################################

-- To be called inside the flows tableCallback
function initFlowsRefreshRows()
   print[[
datatableInitRefreshRows($("#table-flows"), "key_and_hash", 10000, {
   /* List of rows with trend icons */
   "column_thpt": ]] print(ternary(getThroughputType() ~= "bps", "NtopUtils.fpackets", "NtopUtils.bitsToSize")) print[[,
   "column_bytes": NtopUtils.bytesToSize,
});

$("#dt-bottom-details > .float-left > p").first().append('. ]]
   print(i18n('flows_page.idle_flows_not_listed'))
   print[[');]]
end

-- ###########################################

function canRestoreHost(ifid, ip, vlan)
   local ip_to_mac = string.format("ntopng.ip_to_mac.ifid_%u__%s@%d", ifid, ip, vlan)
   local key_to_check

   -- Check if there is a MAC address associated
   local mac = ntop.getCache(ip_to_mac)

   if not isEmptyString(mac) then
      key_to_check = string.format("ntopng.serialized_hostsbymac.ifid_%u__%s_%s", ifid, mac, ternary(isIPv4(ip), "v4", "v6"))
   else
      key_to_check = string.format("ntopng.serialized_hosts.ifid_%u__%s@%d", ifid, ip, vlan)
   end

   return(not table.empty(ntop.getKeysCache(key_to_check)))
end

-- ###########################################

--- Test if each element inside the table t satisfies the predicate function
--- @param t table The table containing values to test
--- @param predicate function The function that return a boolean value (true|false)
--- @return boolean
function table.all(t, predicate)

   if type(t) ~= 'table' then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, "the first paramater is not a table!")
      return false
   end
   if type(predicate) ~= 'function' then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, "the passed predicate is not a function!")
      return false
   end

   if t == nil then return false end

   for _, value in pairs(t) do

      -- check if the value satisfies the boolean predicate
      local term = predicate(value)

      -- if the return value is valid and true then do nothing
      -- otherwise stop the loop and return false
      if term == nil then
         -- inform the client about the nil value
         traceError(TRACE_DEBUG, TRACE_CONSOLE, "a null term has been returned from the predicate function!")
         return false
      elseif not term then
         return false
      end
   end

   -- each entry satisfies the predicate
   return true
end

-- ###########################################

--- Perform a linear search to check if an element is inside a table
--- @param t table The table to scan
--- @param needle any The element to search
--- @param comp function The compare function used to compare the searched element with others
--- @return boolean True if the element is insie the table, False otherwise
function table.contains(t, needle, comp)

   if (t == nil) then return false end
   if (type(t) ~= "table") then return false end
   if (#t == 0) then return false end

   local default_compare = (function(e) return e == needle end)
   comp = comp or default_compare

   for _, element in ipairs(t) do
      if comp(element) then return true end
   end

   return false
end

-- ###########################################

function build_query_url(excluded)

   local query = "?"

   for key, value in pairs(_GET) do
      if not(table.contains(excluded, key)) then
         query = query .. string.format("%s=%s&", key, value)
      end
   end

   return query
end

-- ###########################################

function build_query_params(params)

    local query = "?"
    local t = {}
 
    for key, value in pairs(params) do
        t[#t+1] = string.format("%s=%s", key, value)
    end

    return query .. table.concat(t, '&')
end

-- ###########################################

function create_ndpi_proto_name(v)
   local app = ""

   if v["proto.ndpi"] then
      app = getApplicationLabel(v["proto.ndpi"])
   else
      local master_proto = interface.getnDPIProtoName(tonumber(v["l7_master_proto"]))
      local app_proto    = interface.getnDPIProtoName(tonumber(v["l7_proto"]))

      if master_proto == app_proto then
         app = app_proto
      elseif master_proto == "Unknown" then
         app = app_proto
      else
         app = master_proto

         if app_proto ~= "Unknown" then
            app = app .. "." .. app_proto
         end
      end
           
      app = getApplicationLabel(app)  
   end

   return app
end

-- ###########################################

--- Insert an element inside the table if is not present
function table.insertIfNotPresent(t, element, comp)
   if table.contains(t, element, comp) then return end
   t[#t+1] = element
end

-- ###########################################

--- Fold right table with a custom function
--- @param t table Table to fold
--- @param func function Function to execute on table values
--- @param val any The returned default value
function table.foldr(t, func, val)
   for i,v in pairs(t) do
       val = func(val, v)
   end
   return val
end

-- ###########################################

function table.has_key(table, key)
   return table[key] ~= nil
end

-- ###########################################

local cache = {}

function buildHostHREF(ip_address, vlan_id, page)
   local stats = cache[ip_address]

   if(stats == nil) then
      stats = interface.getHostInfo(ip_address, vlan_id)
      cache[ip_address] = { stats = stats }
   else
      stats = stats.stats
   end

   if(stats == nil) then
      return(ip_address)
   else
      local hinfo = hostkey2hostinfo(ip_address)
      local name  = hostinfo2label(hinfo)
      local res

      if((name == nil) or (name == "")) then name = ip_address end
      res = '<A HREF="'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='..ip_address
      if(vlan_id and (vlan_id ~= 0)) then res = res .. "@"..vlan_id end
      res = res  ..'&page='..page..'">'..name..'</A>'

      return(res)
   end
end

function builMapHREF(ip_address, vlan_id, map, default_page)

   local stats = cache[ip_address]

   if(stats == nil) then
      stats = interface.getHostInfo(ip_address, vlan_id)
      cache[ip_address] = { stats = stats }
   else
      stats = stats.stats
   end

   if(stats == nil) then
      return(ip_address)
   else
      local hinfo = hostkey2hostinfo(ip_address)
      local hmininfo = interface.getHostMinInfo(hinfo.host, hinfo.vlan)
      for key, value in pairs(hmininfo) do
          hinfo[key] = value
      end
      
      local name  = hostinfo2label(hinfo)
      local res

      if((name == nil) or (name == "")) then name = ip_address end
      res = '<a href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/'..map..'_map.lua?host='..ip_address

      if(vlan_id and (vlan_id ~= 0)) then res = res .. "@"..vlan_id end
      res = res  ..'&page='..default_page..'">'..name..'</A>'

      return(res)
   end
end

-- #####################

function formatAlertAHref(key, value, label)
   return "<a class='tag-filter' data-tag-key='" .. key .. "' title='" .. value .. "' data-tag-value='" .. value .. "' data-tag-label='" .. label .. "' href='#'>" .. label .. "</a>"
end

-- #####################

local iec104_typeids = {
   M_SP_NA_1=0x01,
   M_SP_TA_1=0x02,
   M_DP_NA_1=0x03,
   M_DP_TA_1=0x04,
   M_ST_NA_1=0x05,
   M_ST_TA_1=0x06,
   M_BO_NA_1=0x07,
   M_BO_TA_1=0x08,
   M_ME_NA_1=0x09,
   M_ME_TA_1=0x0A,
   M_ME_NB_1=0x0B,
   M_ME_TB_1=0x0C,
   M_ME_NC_1=0x0D,
   M_ME_TC_1=0x0E,
   M_IT_NA_1=0x0F,
   M_IT_TA_1=0x10,
   M_EP_TA_1=0x11,
   M_EP_TB_1=0x12,
   M_EP_TC_1=0x13,
   M_PS_NA_1=0x14,
   M_ME_ND_1=0x15,
   M_SP_TB_1=30,
   M_DP_TB_1=31,
   M_ST_TB_1=32,
   M_BO_TB_1=33,
   M_ME_TD_1=34,
   M_ME_TE_1=35,
   M_ME_TF_1=36,
   M_IT_TB_1=37,
   M_EP_TD_1=38,
   M_EP_TE_1=39,
   M_EP_TF_1=40,
   ASDU_TYPE_41=41,
   ASDU_TYPE_42=42,
   ASDU_TYPE_43=43,
   ASDU_TYPE_44=44,
   C_SC_NA_1=45,
   C_DC_NA_1=46,
   C_RC_NA_1=47,
   C_SE_NA_1=48,
   C_SE_NB_1=49,
   C_SE_NC_1=50,
   C_BO_NA_1=51,
   C_SC_TA_1=58,
   C_DC_TA_1=59,
   C_RC_TA_1=60,
   C_SE_TA_1=61,
   C_SE_TB_1=62,
   C_SE_TC_1=63,
   C_BO_TA_1=64,
   M_EI_NA_1=70,
   C_IC_NA_1=100,
   C_CI_NA_1=101,
   C_RD_NA_1=102,
   C_CS_NA_1=103,
   C_TS_NA_1=104,
   C_RP_NA_1=105,
   C_CD_NA_1=106,
   C_TS_TA_1=107,
   P_ME_NA_1=110,
   P_ME_NB_1=111,
   P_ME_NC_1=112,
   P_AC_NA_1=113,
   F_FR_NA_1=120,
   F_SR_NA_1=121,
   F_SC_NA_1=122,
   F_LS_NA_1=123,
   F_FA_NA_1=124,
   F_SG_NA_1=125,
   F_DR_TA_1=126,
}

function iec104_typeids2str(c)
   if(c == nil) then return end

   for s,v in pairs(iec104_typeids) do
      if(v == c) then
	 return(s.." (".. v ..")")
      end
   end

   return(c)
end

function table.slice(t, start_table, end_table) 
    if t == nil then
        error("The array to slice cannot be nil!")
    end

    if end_table > #t then
       end_table = #t
    end

    if start_table < 1 then
        error("Invalid bounds!")
    end

    local res = {}
    for i = start_table, end_table, 1 do
        res[#res + 1] = t[i]
    end

    return res
end

--
-- IMPORTANT
-- Leave it at the end so it can use the functions
-- defined in this file
--
http_lint = require "http_lint"

