--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local discover = require "discover_utils"
local json = require "dkjson"
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

-- Table parameters
local all = _GET["all"]
local currentPage = _GET["currentPage"]
local perPage     = _GET["perPage"]
local sortColumn  = _GET["sortColumn"]
local sortOrder   = _GET["sortOrder"]
local protocol    = _GET["protocol"]
local long_names  = _GET["long_names"]
local criteria    = _GET["criteria"]
local traffic_type= _GET["traffic_type"]

-- Host comparison parameters
local mode        = _GET["mode"]
local tracked     = _GET["tracked"]
local ipversion   = _GET["version"]

-- Used when filtering by ASn, VLAN or network
local asn          = _GET["asn"]
local vlan         = _GET["vlan"]
local network      = _GET["network"]
local pool         = _GET["pool"]
local country      = _GET["country"]
local os_          = _GET["os"]
local mac          = _GET["mac"]
local top_hidden   = ternary(_GET["top_hidden"] == "1", true, nil)

function update_host_name(h)
   if(h["name"] == nil) then
      if(h["ip"] ~= nil) then
	 h["name"] = getResolvedAddress(hostkey2hostinfo(h["ip"]))
      else
	 h["name"] = h["mac"]
      end
   end

   return(h["name"])
end

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

if(long_names == nil) then
   long_names = false
else
   if(long_names == "1") then
      long_names = true
   else
      long_names = false
   end
end

local criteria_key, criteria_format
local sortPrefs = "hosts"
if(criteria ~= nil) then
   criteria_key, criteria_format = label2criteriakey(criteria)
   sortPrefs = "localhosts_"..criteria
   mode = "local"
end

if((sortColumn == nil) or (sortColumn == "column_"))then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
      and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs,sortColumn)
   end
end

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder(sortPrefs)
else
   if((sortColumn ~= "column_")
      and (sortColumn ~= "")) then
      tablePreferences("sort_order_"..sortPrefs,sortOrder)
   end
end


if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number",perPage)
end

local one_way_traffic
if(traffic_type == "one_way") then one_way_traffic = true end
if(tracked ~= nil) then tracked = tonumber(tracked) else tracked = 0 end

if((mode == nil) or (mode == "")) then mode = "all" end

interface.select(ifname)

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end

local filtered_hosts = false
local blacklisted = false

local hosts_retrv_function = interface.getHostsInfo
if mode == "local" then
   hosts_retrv_function = interface.getLocalHostsInfo
elseif mode == "remote" then
   hosts_retrv_function = interface.getRemoteHostsInfo
elseif mode == "broadcast_domain" then
   hosts_retrv_function = interface.getBroadcastDomainHostsInfo
elseif mode == "filtered" then
   filtered_hosts = true
elseif mode == "blacklisted" then
   blacklisted_hosts = true
end

local hosts_stats = hosts_retrv_function(false, sortColumn, perPage, to_skip, sOrder,
					 country, os_, tonumber(vlan), tonumber(asn),
					 tonumber(network), mac,
					 tonumber(pool), tonumber(ipversion),
					 tonumber(protocol), one_way_traffic,
					 filtered_hosts, blacklisted_hosts, top_hidden) -- false = little details

if(hosts_stats == nil) then total = 0 else total = hosts_stats["numHosts"] end
hosts_stats = hosts_stats["hosts"]
-- for k,v in pairs(hosts_stats) do io.write(k.." ["..sortColumn.."]\n") end

if(all ~= nil) then
   perPage = 0
   currentPage = 0
end

local now = os.time()
local vals = {}

local num = 0
if(hosts_stats ~= nil) then
   for key, value in pairs(hosts_stats) do
      num = num + 1
      postfix = string.format("0.%04u", num)

      -- io.write("==>"..key.."\n")
      -- tprint(hosts_stats[key])
      -- io.write("==>"..hosts_stats[key]["bytes.sent"].."[" .. sortColumn .. "]["..key.."]\n")

      if(sortColumn == "column_") then
	 vals[key] = key -- hosts_stats[key]["ipkey"]
      elseif(sortColumn == "column_name") then
	 hosts_stats[key]["name"] = update_host_name(hosts_stats[key])
	 vals[hosts_stats[key]["name"]..postfix] = key
      elseif(sortColumn == "column_since") then
	 vals[hosts_stats[key]["seen.first"]+postfix] = key
      elseif(sortColumn == "column_alerts") then
	 vals[hosts_stats[key]["num_alerts"]+postfix] = key
      elseif(sortColumn == "column_last") then
	 vals[hosts_stats[key]["seen.last"]+postfix] = key
      elseif(sortColumn == "column_country") then
	 vals[hosts_stats[key]["country"]..postfix] = key
      elseif(sortColumn == "column_vlan") then
	 vals[hosts_stats[key]["vlan"]..postfix] = key
      elseif(sortColumn == "column_num_flows") then
	 local t = hosts_stats[key]["active_flows.as_client"]+hosts_stats[key]["active_flows.as_server"]
	 vals[t+postfix] = key
      elseif(sortColumn == "column_num_dropped_flows") then
	 local t = hosts_stats[key]["flows.dropped"] or 0
	 vals[t+postfix] = key
      elseif(sortColumn == "column_traffic") then
	 vals[hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]+postfix] = key
      elseif(sortColumn == "column_thpt") then
	 vals[hosts_stats[key]["throughput_"..throughput_type]+postfix] = key
      elseif(sortColumn == "column_queries") then
	 vals[hosts_stats[key]["queries.rcvd"]+postfix] = key
      elseif(sortColumn == "column_ip") then
	 vals[hosts_stats[key]["ipkey"]+postfix] = key
	 -- looking_glass_criteria
      elseif(criteria ~= nil) then
	 -- io.write("==> "..criteria.."\n")
	 if(sortColumn == "column_"..criteria) then
	    local c = hosts_stats[key]["criteria"]

	    if(c ~= nil) then
	       vals[c[criteria_key]+postfix] = key
	       -- io.write(key.."="..hosts_stats[key]["criteria"][criteria_key].."\n")
	    end
	 end
      end
   end
end

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

local formatted_res = {}

for _key, _value in pairsByKeys(vals, funct) do
   local record = {}
   local key = vals[_key]
   local value = hosts_stats[key]

   local symkey = hostinfo2jqueryid(hosts_stats[key])
   record["key"] = symkey

   local url = ntop.getHttpPrefix().."/lua/host_details.lua?" ..hostinfo2url(hosts_stats[key])

   local drop_traffic = false
   if have_nedge and ntop.getHashCache("ntopng.prefs.drop_host_traffic", key) == "true" then
      drop_traffic = true
   end

   local column_ip = "<A HREF='"..url.."' "..
      ternary((have_nedge and drop_traffic), "style='text-decoration: line-through'", "")..
      ">"..mapOS2Icon(stripVlan(key)).." </A>"

   if((value.operatingSystem ~= 0) and (value["os"] == "")) then
      column_ip = column_ip .. " "..getOperatingSystemIcon(value.operatingSystem)
   end

   if value["systemhost"]    then column_ip = column_ip .. "&nbsp;<i class='fa fa-flag'></i> " end
   if value["hiddenFromTop"] then column_ip = column_ip .. "&nbsp;<i class='fa fa-eye-slash'></i> " end
   if value["childSafe"]     then column_ip = column_ip .. getSafeChildIcon() end

   local host = interface.getHostInfo(hosts_stats[key].ip, hosts_stats[key].vlan)
   if((host ~= nil) and (host.country ~= nil) and (host.country ~= "")) then
      column_ip = column_ip .."&nbsp;<a href='".. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country="..host.country.."'><img src='".. ntop.getHttpPrefix() .. "/img/blank.gif' class='flag flag-".. string.lower(host.country) .."'></a> "
   end

   local icon = getOSIcon(value["os"])
   if(host ~= nil) then
      icon = icon .." ".. discover.devtype2icon(host.devtype)
   end
   icon = icon:gsub('"',"'")
   column_ip = column_ip .. icon

   if((host ~= nil) and (host.ip ~= "0.0.0.0") and (not string.contains(host.ip, ":"))) then
      if(value.dhcpHost) then column_ip = column_ip .. "&nbsp;<i class='fa fa-flash fa-lg' title='DHCP Host'></i>" end
   end

   if((host ~= nil) and (host["is_blacklisted"] == true)) then
      column_ip = column_ip .. "&nbsp;<span class='label label-danger'>"..i18n("hosts_stats.label_blacklisted_host").."</span>"
   end

   record["column_ip"] = column_ip

   if(url ~= nil) then
      record["column_url"] = url
   end

   if(value["name"] == nil) then
      value["name"] = getResolvedAddress(hostkey2hostinfo(key))
   end

   if(value["name"] == "") then
      value["name"] = key
   end

   local column_name

   if(long_names) then
      column_name = value["name"]
   else
      column_name = shortHostName(value["name"])
   end

   if(value["ip"] ~= nil) then
      local label = getHostAltName(value["ip"], value["mac"])
      if(label ~= value["ip"]) then
	 column_name = column_name .. " ["..label.."]"
      end
   end

   if((value["num_alerts"] ~= nil) and (value["num_alerts"] > 0)) then
      column_name = column_name .. " <i class='fa fa-warning fa-lg' style='color: #B94A48;'></i>"
   end

   if value["has_blocking_quota"] or value["has_blocking_shaper"] then
      column_name = column_name .. " <i class='fa fa-ban fa-lg' title='"..i18n("hosts_stats.blocking_traffic_policy_popup_msg").."'></i>"
   end

   record["column_name"] = column_name

   local column_vlan
   if(value["vlan"] ~= nil) then
      if(value["vlan"] ~= 0) then
	 column_vlan = value["vlan"]
      else
	 column_vlan = 0
      end
   end

   record["column_since"] = secondsToTime(now-value["seen.first"] + 1)
   record["column_last"] = secondsToTime(now-value["seen.last"] + 1)

   if((criteria_key ~= nil) and (value["criteria"] ~= nil)) then
      record["column_"..criteria] = criteria_format(value["criteria"][criteria_key])
   end

   if((value["throughput_trend_"..throughput_type] ~= nil) and
      (value["throughput_trend_"..throughput_type] > 0)) then

      local column_thpt
      if(throughput_type == "pps") then
	 column_thpt = pktsToSize(value["throughput_pps"])
      else
	 column_thpt = bitsToSize(8*value["throughput_bps"])
      end

      if(value["throughput_trend_"..throughput_type] == 1) then
	 column_thpt = column_thpt .. " <i class='fa fa-arrow-up'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 2) then
	 column_thpt = column_thpt .. " <i class='fa fa-arrow-down'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 3) then
	 column_thpt = column_thpt .. " <i class='fa fa-minus'></i>"
      end
      record["column_thpt"] = column_thpt

   else
      record["column_thpt"] = "0 "..throughput_type
   end

   local column_info = "<a href='"
      ..ntop.getHttpPrefix().."/lua/host_details.lua?page=flows&"..hostinfo2url(value).."'>"
      .."<span class='label label-info'>"..i18n("flows").."</span>"
      .."</a>"

   if have_nedge and (host ~= nil) and (host.localhost or host.systemhost) then
      column_info = column_info.." <span title='"..
	 (ternary(drop_traffic, i18n("host_config.unblock_host_traffic"), i18n("host_config.drop_all_host_traffic")))..
	 "' class='label label-"..(ternary(drop_traffic, "danger", "default")).." block-badge' "..
	 (ternary(isAdministrator(), "onclick='block_host(\\\""..symkey.."\\\", \\\""..hostinfo2url(value)..
		     "\\\");' style='cursor: pointer;'", "")).."><i class='fa fa-ban' /></span>"
   end

   record["column_info"] = column_info
   record["column_traffic"] = bytesToSize(value["bytes.sent"]+value["bytes.rcvd"])
   record["column_alerts"] = tostring((value["num_alerts"] or 0))

   if(value["localhost"] ~= nil or value["systemhost"] ~= nil) then
      local column_location = ""
      if value["localhost"] == true --[[or value["systemhost"] == true --]] then
	 column_location = "<span class='label label-success'>"..i18n("hosts_stats.label_local_host").."</span>"
      elseif value["is_multicast"] == true then
	 column_location = "<span class='label label-default'>Multicast</span>"
      elseif value["is_broadcast"] == true then
	 column_location = "<span class='label label-default'>Broadcast</span>"
      else
	 column_location = "<span class='label label-default'>"..i18n("hosts_stats.label_remote_host").."</span>"
      end

      if value["broadcast_domain_host"] then
	 column_location = column_location.." <span class='label label-info'><i class='fa fa-sitemap' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i></span>"
      end

      record["column_location"] = column_location
   end

   record["column_num_flows"] = tostring(value["active_flows.as_client"] + value["active_flows.as_server"])

   -- exists only for bridged interfaces
   if isBridgeInterface(interface.getStats()) then
      record["column_num_dropped_flows"] = (value["flows.dropped"] or 0)
   end

   local sent2rcvd = round((value["bytes.sent"] * 100) / (value["bytes.sent"]+value["bytes.rcvd"]), 0)
   if(sent2rcvd == nil) then sent2rcvd = 0 end
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
	     .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   formatted_res[#formatted_res + 1] = record
end -- for

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

local result = {}

result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = total
result["data"] = formatted_res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
