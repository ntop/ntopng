--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
local discover = require "discover_utils"
local custom_column_utils = require "custom_column_utils"
local format_utils = require "format_utils"
local json = require "dkjson"
local vs_utils = require "vs_utils"
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/json')

-- Table parameters
local all           = _GET["all"]
local currentPage   = _GET["currentPage"]
local perPage       = _GET["perPage"]
local sortColumn    = _GET["sortColumn"]
local sortOrder     = _GET["sortOrder"]
local protocol      = _GET["protocol"]
local custom_column = _GET["custom_column"]
local traffic_type  = _GET["traffic_type"]
local device_ip     = _GET["deviceIP"]

-- Host comparison parameters
local mode          = _GET["mode"]
local tracked       = _GET["tracked"]
local ipversion     = _GET["version"]

-- Used when filtering by ASn, VLAN or network
local asn          = _GET["asn"]
local vlan         = _GET["vlan"]
local network      = _GET["network"]
local cidr         = _GET["network_cidr"]
local pool         = _GET["pool"]
local country      = _GET["country"]
local os_          = tonumber(_GET["os"])
local mac          = _GET["mac"]

function update_host_name(h)
   if(h["name"] == nil) then
      if(h["ip"] ~= nil) then
         h["name"] = ip2label(h["ip"])
      else
	 h["name"] = h["mac"]
      end
   end

   return(h["name"])
end

-- Get from redis the throughput type bps or pps
local throughput_type = getThroughputType()

local sortPrefs = "hosts"

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

local custom_column_key, custom_column_format
local traffic_type_filter

if traffic_type == "one_way" then
   traffic_type_filter = 1 -- ntop_typedefs.h TrafficType traffic_type_one_way
elseif traffic_type == "bidirectional" then
   traffic_type_filter = 2 -- ntop_typedefs.h TrafficType traffic_type_bidirectional
end

if(tracked ~= nil) then tracked = tonumber(tracked) else tracked = 0 end

if((mode == nil) or (mode == "")) then mode = "all" end

interface.select(ifname)

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end

local filtered_hosts = false
local blacklisted = false
local anomalous = false
local dhcp_hosts = false

local hosts_retrv_function = interface.getHostsInfo

if mode == "local" then
   hosts_retrv_function = interface.getLocalHostsInfo
elseif mode == "local_no_tx" then
   hosts_retrv_function = interface.getLocalHostsInfoNoTX
elseif mode == "local_no_tcp_tx" then
   hosts_retrv_function = interface.getLocalHostsInfoNoTXTCP
elseif mode == "remote" then
   hosts_retrv_function = interface.getRemoteHostsInfo
elseif mode == "remote_no_tx" then
   hosts_retrv_function = interface.getRemoteHostsInfoNoTX
elseif mode == "remote_no_tcp_tx" then
   hosts_retrv_function = interface.getRemoteHostsInfoNoTXTCP
elseif mode == "broadcast_domain" then
   hosts_retrv_function = interface.getBroadcastDomainHostsInfo
elseif mode == "broadcast_multicast" then
   hosts_retrv_function = interface.getBroadcastMulticastHostsInfo
elseif mode == "filtered" then
   filtered_hosts = true
elseif mode == "blacklisted" then
   blacklisted_hosts = true
elseif mode == "dhcp" then
   dhcp_hosts = true
end

local hosts_stats = hosts_retrv_function(false, sortColumn, perPage, to_skip, sOrder,
					 country, os_, tonumber(vlan), tonumber(asn),
					 tonumber(network), mac,
					 tonumber(pool), tonumber(ipversion),
					 tonumber(protocol), traffic_type_filter,
					 filtered_hosts, blacklisted_hosts,
					 anomalous, dhcp_hosts, cidr, device_ip)

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

      -- Safety check (trace failure for debugging)
      if type(value) ~= "table" then
         traceError(TRACE_WARNING, TRACE_CONSOLE, "Unexpected value for key = "..key.." (not a table)")
	 tprint(value)
	 goto skip
      end

      local hosts_vs_details = vs_utils.retrieve_hosts_to_scan()
      local host_vs_details = {}
      for _,value in ipairs(hosts_vs_details) do
          if value.host == key then
              host_vs_details = value
              break
          end
      end
      

      if(sortColumn == "column_") then
	 vals[key] = key -- hosts_stats[key]["ipkey"]
      elseif(sortColumn == "column_name") then
	 hosts_stats[key]["name"] = update_host_name(hosts_stats[key])
         vals[hosts_stats[key]["name"]..postfix] = key
      elseif(sortColumn == "column_since") then
         vals[hosts_stats[key]["seen.first"]+postfix] = key
      elseif(sortColumn == "column_alerts") then
         vals[hosts_stats[key]["seen.first"]+postfix] = key
      elseif(sortColumn == "column_score") then
	 if(hosts_stats[key]["score"] ~= nil) then
	    vals[hosts_stats[key]["score"]+postfix] = key
	 end
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
	 local v = hosts_stats[key]["throughput_"..throughput_type]

	 if(v ~= nil) then
	    vals[v+postfix] = key
	 end
      elseif(sortColumn == "column_queries") then
	 vals[hosts_stats[key]["queries.rcvd"]+postfix] = key
      elseif(sortColumn == "column_ip") then
	 vals[hosts_stats[key]["iphex"]..postfix] = key
      elseif(sortColumn == "column_num_vulnerabilities") then
         if(host_vs_details.num_vulnerabilities_found ~= nil) then
            vals[host_vs_details.num_vulnerabilities_found..postfix] = key
         else
            vals["0"..postfix] = key
         end
      elseif custom_column_utils.isCustomColumn(sortColumn) then
	 custom_column_key, custom_column_format = custom_column_utils.label2criteriakey(sortColumn)
	 local val = custom_column_utils.hostStatsToColumnValue(hosts_stats[key], custom_column_key, false)

	 if(val == nil) then val = 0 end -- Just to avoid invalid table values
	 
	 if(tonumber(val)) then
	    vals[val + postfix] = key
	 else
	    vals[val..postfix] = key
	 end
      else
	 vals[key] = key
      end

      ::skip::
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

   

   local hosts_vs_details = vs_utils.retrieve_hosts_to_scan()
    local host_vs_details = {}
    for _,value in ipairs(hosts_vs_details) do
        if value.host == key then
            host_vs_details = value
            break
        end
    end

    if (host_vs_details and host_vs_details.num_vulnerabilities_found ~= nil and host_vs_details.num_vulnerabilities_found > 0) then
      
         
        record["column_num_vulnerabilities"] = format_high_num_value_for_tables({
                                             value = host_vs_details.num_vulnerabilities_found
                                          }, "value")
    end
   

   local symkey = hostinfo2jqueryid(hosts_stats[key])
   record["key"] = symkey

   local url = hostinfo2detailsurl(hosts_stats[key])

   local drop_traffic = false
   if have_nedge and ntop.getHashCache("ntopng.prefs.drop_host_traffic", key) == "true" then
      drop_traffic = true
   end

   local column_ip = "<A HREF='"..url.."' "..
      ternary((have_nedge and drop_traffic), "style='text-decoration: line-through'", "")..
      ">".. stripVlan(key) .." </A>"

   if((value.os ~= 0) and (value["os"] == "")) then
      column_ip = column_ip .. " ".. discover.getOsIcon(value.os)
   end

   if((value["num_alerts"] ~= nil) and (value["num_alerts"] > 0)) then
      column_ip = column_ip .. " <i class='fas fa-exclamation-triangle' style='color: #B94A48;'></i>"
   end

   if value["systemhost"]    then column_ip = column_ip .. "&nbsp;<i class='fas fa-flag'></i> " end
   if value["hiddenFromTop"] then column_ip = column_ip .. "&nbsp;<i class='fas fa-eye-slash'></i> " end
   if value["childSafe"]     then column_ip = column_ip .. getSafeChildIcon() end

   local host = interface.getHostInfo(hosts_stats[key].ip, hosts_stats[key].vlan)

   local icon = discover.getOsIcon(value["os"])
   if(host ~= nil) then
      icon = icon .." ".. discover.devtype2icon(host.devtype)
   end
   icon = icon:gsub('"',"'")
   column_ip = column_ip .. icon

   if((host ~= nil) and (host.ip ~= "0.0.0.0")) then
      if(value.dhcpHost) then column_ip = column_ip .. "&nbsp;<i class='fas fa-flash fa-lg' title='DHCP Host'></i>" end
   end

   if(url ~= nil) then
      record["column_url"] = url
   end

   local column_name = ''
   if host then
      if host["name"] then
	 column_name = shortenString(host["name"], 36)
      end

      -- This is the label as set-up by the user
      local alt_name = getHostAltName(host["ip"])
      if not isEmptyString(alt_name) and alt_name ~= column_name then
	 column_name = string.format("%s [%s]", column_name, shortenString(alt_name))
      end
   end

   if value["has_blocking_quota"] or value["has_blocking_shaper"] then
      column_name = column_name .. " <i class='fas fa-hourglass' title='"..i18n("hosts_stats.blocking_traffic_policy_popup_msg").."'></i>"
   end

   if(host and (column_name == host.ip)) then
      record["column_name"] = ""
   else
      record["column_name"] = column_name
   end

   if value["vlan"] > 0 then
      record["column_vlan"] = getFullVlanName(value["vlan"])
   end

   record["column_since"] = secondsToTime(now-value["seen.first"] + 1)
   record["column_last"] = secondsToTime(now-value["seen.last"] + 1)

   if((value["throughput_trend_"..throughput_type] ~= nil) and
      (value["throughput_trend_"..throughput_type] > 0)) then

      local column_thpt
      if(throughput_type == "pps") then
	 column_thpt = pktsToSize(value["throughput_pps"])
      else
	 column_thpt = bitsToSize(8*value["throughput_bps"])
      end

      if(value["throughput_trend_"..throughput_type] == 1) then
	 column_thpt = column_thpt .. " <i class='fas fa-arrow-up'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 2) then
	 column_thpt = column_thpt .. " <i class='fas fa-arrow-down'></i>"
      elseif(value["throughput_trend_"..throughput_type] == 3) then
	 column_thpt = column_thpt .. " <i class='fas fa-minus'></i>"
      end
      record["column_thpt"] = column_thpt

   else
      record["column_thpt"] = "0 "..throughput_type
   end

   local column_info = hostinfo2detailshref(value, {page = "flows"}, "<span class='btn btn-sm btn-info'><i class='fas fa-stream'></i></span>")

   if have_nedge and (host ~= nil) and (host.localhost or host.systemhost) then
      column_info = column_info.." <span title='"..
	 (ternary(drop_traffic, i18n("host_config.unblock_host_traffic"), i18n("host_config.drop_all_host_traffic")))..
	 "' class='btn btn-sm "..(ternary(drop_traffic, "btn-danger", "btn-secondary")).." block-badge' "..
	 (ternary(isAdministrator(), "onclick='block_host(\""..symkey.."\", \""..hostinfo2url(value)..
		     "\");' style='cursor: pointer;'", "")).."><i class='fas fa-ban' /></span>"
   end

   record["column_info"] = column_info
   record["column_traffic"] = bytesToSize(value["bytes.sent"]+value["bytes.rcvd"])
   record["column_alerts"] = tostring((value["num_alerts"] or 0))

   local column_location = ""
   if(value["localhost"] ~= nil or value["systemhost"] ~= nil) then
      column_location = format_utils.formatMainAddressCategory(host)
   end

   record["column_ip"] = column_ip .. column_location

   value["num_flows"] = value["active_flows.as_client"] + value["active_flows.as_server"]
   record["column_num_flows"] = format_high_num_value_for_tables(value, "num_flows") 

   -- exists only for bridged interfaces
   if isBridgeInterface(interface.getStats()) then
      record["column_num_dropped_flows"] = (value["flows.dropped"] or 0)
   end

   local sent2rcvd = round((value["bytes.sent"] * 100) / (value["bytes.sent"]+value["bytes.rcvd"]), 0)
   if(sent2rcvd == nil) then sent2rcvd = 0 end
   record["column_score"] = format_high_num_value_for_tables(value, "score") 
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
	     .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   local _, custom_column_key = custom_column_utils.getCustomColumnName()
   record["column_"..custom_column_key] = custom_column_utils.hostStatsToColumnValue(value, custom_column_key, true)

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
