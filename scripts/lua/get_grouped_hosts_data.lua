--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

-- Table parameters
all = _GET["all"]
currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]

group_col   = _GET["grouped_by"]
as_n        = _GET["as"]
vlan_n      = _GET["vlan"]
network_n   = _GET["network"]
country_n   = _GET["country"]
os_n   	    = _GET["os"]

if (group_col == nil) then
   group_col = "asn"
end

-- Get from redis the throughput type bps or pps
throughput_type = getThroughputType()

if ((sortColumn == nil) or (sortColumn == "column_")) then
   sortColumn = getDefaultTableSort(group_col)
   --if(sortColumn == "column_") then sortColumn = "column_name" end	
else
   if ((sortColumn ~= "column_") and (sortColumn ~= "")) then
      tablePreferences("sort_"..group_col,sortColumn)
   end
end

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder(group_col)
else
   if ((sortColumn ~= "column_") and (sortColumn ~= "")) then
      tablePreferences("sort_order_"..group_col,sortOrder)
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

interface.select(ifname)

if((group_col == "mac") or (group_col == "antenna_mac")) then
   hosts_stats,total = aggregateHostsStats(interface.getLocalHostsInfo(false))
   --PRINT
   -- for n in pairs(hosts_stats) do 
   --    io.write("= "..n..'\n')
   -- end
else
--[[
   hosts_stats,total = interface.getGroupedHosts(
					      tonumber(vlan_n) or 0,
					      tonumber(as_n) or 0,
					      tonumber(network_n) or -1,
					      country_n or "", os_n or "")
--]]
   hosts_stats,total = aggregateHostsStats(interface.getHostsInfo(false))
--   tprint(hosts_stats)
end

to_skip = (currentPage-1) * perPage

if (all ~= nil) then
   perPage = 0
   currentPage = 0
end

if (as_n == nil and vlan_n == nil and network_n == nil and country_n == nil and os_n == nil) then -- single group info requested
   print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
end
num = 0
total = 0

now = os.time()
vals = {}

stats_by_group_col = {}

--[[
The idea here is to group host statistics by the value specified in
group_col. For example, if group_col=='local_network_id', then statistics
will be grouped by values of 'local_network_id'. 

group_col value will be read for each host, and statistics matching this value
will be incremented with single host statistics.

So for example, if group_col=='local_network_id', and:
** hosts 192.168.1.1 and 192.168.1.2  have local_network_id == '1'
** hosts 10.0.0.1 and 10.0.0.2 have local_network_id == '2'

resulting statistics will have two keys: 1 and 2 -- that is local_network_id
values. Key 1 will contain the sum of statistics for hosts 192.168.1.1 and
192.168.1.2. Key 2 will contain the sum of statistics for hosts 10.0.0.1
and 10.0.0.0.2
--]]
for key,value in pairs(hosts_stats) do
   --[[
   key is a host, expressed as a string, e.g., 192.168.2.113
   value is a table containing all host-related information
   e.g., local_network_id
   --]]
   if(value[group_col] ~= nil) then
      -- Convert grouping identifier to string to avoid type mismatches if the
      -- value is 0 (which would mean that the AS is private)
      value[group_col] = tostring(value[group_col])

      id = value[group_col]
      
      existing = stats_by_group_col[id]
      if (existing == nil) then
	 stats_by_group_col[id] = {}
	 stats_by_group_col[id]["id"] = id
	 if (group_col == "asn") then
	    if (id ~= "0") then
	       stats_by_group_col[id]["name"] = value["asname"]
	    else
	       stats_by_group_col[id]["name"] = "Private ASN"
	    end
	 elseif (group_col == "local_network_id") then
	    stats_by_group_col[id]["name"] = value["local_network_name"]
	    if (stats_by_group_col[id]["name"] == nil) then
	       stats_by_group_col[id]["name"] = "Unknown network"
	    end

	 elseif (group_col == "os") then
	    stats_by_group_col[id]["name"] = value["os"]
	    if (stats_by_group_col[id]["name"] == nil) then
	       stats_by_group_col[id]["name"] = "Unknown OS"
	    end

	 elseif (group_col == "mac") then
	    stats_by_group_col[id]["name"] = value["mac"]

	    --PRINT
	    -- io.write("MAC = "..value["mac"]..'\n')
	    
	    if (stats_by_group_col[id]["name"] == nil) then
	       stats_by_group_col[id]["name"] = "Unknown MAC"
	    end

	 elseif (group_col == "country") then
	    stats_by_group_col[id]["name"] = value["country"]
	    if (stats_by_group_col[id]["name"] == nil) then
	       stats_by_group_col[id]["name"] = "Unknown country"
	    end

	 else
	    stats_by_group_col[id]["name"] = "VLAN"
	 end
	 stats_by_group_col[id]["seen.first"] = value["seen.first"]
	 stats_by_group_col[id]["seen.last"] = value["seen.last"]
      else
	 stats_by_group_col[id]["seen.first"] =
	    math.min(stats_by_group_col[id]["seen.first"], value["seen.first"])
	 stats_by_group_col[id]["seen.last"] =
	    math.max(stats_by_group_col[id]["seen.last"], value["seen.last"])
      end

      stats_by_group_col[id]["num_hosts"] = 1 + ternary(existing, stats_by_group_col[id]["num_hosts"], 0)
      stats_by_group_col[id]["num_alerts"] = value["num_alerts"] + ternary(existing, stats_by_group_col[id]["num_alerts"], 0)
      stats_by_group_col[id]["throughput_bps"] = value["throughput_bps"] + ternary(existing, stats_by_group_col[id]["throughput_bps"], 0)
      stats_by_group_col[id]["throughput_pps"] = value["throughput_pps"] + ternary(existing, stats_by_group_col[id]["throughput_pps"], 0)
      stats_by_group_col[id]["throughput_trend_bps_diff"] = math.floor(value["throughput_trend_bps_diff"]) + ternary(existing, stats_by_group_col[id]["throughput_trend_bps_diff"], 0)
      stats_by_group_col[id]["bytes.sent"] = value["bytes.sent"] + ternary(existing, stats_by_group_col[id]["bytes.sent"], 0)
      stats_by_group_col[id]["bytes.rcvd"] = value["bytes.rcvd"] + ternary(existing, stats_by_group_col[id]["bytes.rcvd"], 0)
      stats_by_group_col[id]["country"] = value["country"]
   end
end

--[[
Prepares a json containing table data, together with HTML.
--]]

function print_single_group(value)
   print ('{ ')
   print ('\"key\" : \"'..value["id"]..'\",')

   print ("\"column_id\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/")
   if (group_col == "asn" or as_n ~= nil) then
      print("hosts_stats.lua?asn=" ..value["id"] .. "'>")
   elseif (group_col == "vlan" or vlan_n ~= nil) then
      print("hosts_stats.lua?vlan="..value["id"].."'>")
   elseif (group_col == "country" or country_n ~= nil) then
      print("hosts_stats.lua?country="..value["id"].."'>")
      print("&nbsp&nbsp&nbsp "..getFlag(value["country"]).."&nbsp&nbsp")
   elseif (group_col == "os" or os_n ~= nil) then        
      print("hosts_stats.lua?os=".. string.gsub(value["id"], " ", '%%20')  .."'>")
      if(value["id"] ~= nil ) then
	 print("".. getOSIcon(value["id"]) .."")
      end      
   elseif (group_col == "local_network_id" or network_n ~= nil) then
      print("hosts_stats.lua?network="..value["id"].."'>")
   elseif (group_col == "antenna_mac") then
      print("hosts_stats.lua?antenna_mac="..value["id"].."'>")
   elseif (group_col == "mac") then
      print("hosts_stats.lua?mac="..value["id"].."'>")
      --PRINT
      -- io.write("ID = "..value["id"]..'\n')
   else
      print("hosts_stats.lua'>")
   end

   if (group_col == "local_network_id" or network_n ~= nil) then
      print(value["name"]..'</A> ')
      if(value["id"] ~= "-1") then
	 print('<A HREF='..ntop.getHttpPrefix()..'/lua/network_details.lua?network='..value["id"]..'&page=historical><i class=\'fa fa-area-chart fa-lg\'></i></A>')
      end
      print('", ')

   elseif group_col == "vlan" or vlan_n ~= nil then
      print(value["id"]..'</A> ')
      if value["id"] ~= "0" then
	 print('<A HREF='..ntop.getHttpPrefix()..'/lua/vlan_details.lua?vlan_id='..value["id"]..'&page=historical><i class=\'fa fa-area-chart fa-lg\'></i></A>')
      end
      print('", ')

   elseif((group_col == "mac") or (group_col == "antenna_mac")) then
      print(get_symbolic_mac(value["id"])..'</A>", ')
   else
      print(value["id"]..'</A>", ')
   end

   print('"column_hosts" : "' .. formatValue(value["num_hosts"]) ..'",')

   print ("\"column_alerts\" : \"")
   if((value["num_alerts"] ~= nil) and (value["num_alerts"] > 0)) then
      print("<font color=#B94A48>"..formatValue(value["num_alerts"]).."</font>")
   else
      print("0")
   end
   print('", ')

   --- TODO: name for VLANs?
   if (group_col == "asn" or as_n ~= nil) then
      print("\"column_name\" : \""..printASN(tonumber(value["id"]), value["name"]))
   elseif ( group_col == "country" or country_n ~= nil) then
      print("\"column_name\" : \""..value["id"])
      
   elseif ( group_col == "os" or os_n ~= nil) then
      print("\"column_name\" : \""..value["id"])
   else
      print("\"column_name\" : \""..value["name"])
   end
   print("&nbsp;"..getFlag(value["country"])..'", ')

   print("\"column_since\" : \"" .. secondsToTime(now-value["seen.first"]+1) .. "\", ")

   sent2rcvd = round((value["bytes.sent"] * 100) / (value["bytes.sent"]+value["bytes.rcvd"]), 0)
   print ("\"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
	     .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: "
	     .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>")
   print('", ')

   if (throughput_type == "pps") then
      print ("\"column_thpt\" : \"" .. pktsToSize(value["throughput_pps"]).. " ")
   else
      print ("\"column_thpt\" : \"" .. bitsToSize(8*value["throughput_bps"]).. " ")
   end
   if(value["throughput_trend_bps_diff"] > 0) then
      print("<i class='fa fa-arrow-up'></i>")
   elseif(value["throughput_trend_bps_diff"] < 0) then
      print("<i class='fa fa-arrow-down'></i>")
   else
      print("<i class='fa fa-minus'></i>")
   end
   print('", ')

   print("\"column_traffic\" : \"" .. bytesToSize(value["bytes.sent"]+value["bytes.rcvd"]))

   print("\" } ")
end


if (as_n ~= nil) then
   as_val = stats_by_group_col[as_n]
   if (as_val == nil)then
      print('{}')
   else
      print_single_group(as_val)
   end
   stats_by_group_col = {}
elseif (country_n ~= nil) then
   country_val = stats_by_group_col[country_n]
   if (country_val == nil) then
      print('{}')
   else
      print_single_group(country_val)
   end
   stats_by_group_col = {}

elseif (os_n ~= nil) then
   os_val = stats_by_group_col[os_n]
   if (os_val == nil) then
      print('{}')
   else
      print_single_group(os_val)
   end
   stats_by_group_col = {}
elseif (vlan_n ~= nil) then
   vlan_val = stats_by_group_col[vlan_n]
   if (vlan_val == nil) then
      print('{}')
   else
      print_single_group(vlan_val)
   end
   stats_by_group_col = {}
elseif (network_n ~= nil) then
   network_val = stats_by_group_col[network_n]
   if (network_val == nil) then
      print('{}')
   else
      print_single_group(network_val)
   end
   stats_by_group_col = {}
end

vals = { } 
for key,value in pairs(stats_by_group_col) do
   v = stats_by_group_col[key]    
   if((key ~= nil) and (v ~= nil)) then
      if(sortColumn == "column_id") then
	 vals[key] = key
      elseif(sortColumn == "column_name") then
	 vals[v["name"]] = key
      elseif(sortColumn == "column_hosts") then
	 vals[v["num_hosts"]] = key
      elseif(sortColumn == "column_since") then
	 vals[(now-v["seen.first"])] = key
      elseif(sortColumn == "column_alerts") then
	 vals[(now-v["num_alerts"])] = key
      elseif(sortColumn == "column_last") then
	 vals[(now-stats_by_group_key[col]["seen.last"]+1)] = key
      elseif(sortColumn == "column_thpt") then
	 vals[v["throughput_"..throughput_type]] = key
      elseif(sortColumn == "column_queries") then
	 vals[v["queries.rcvd"]] = key
      else
	 vals[(v["bytes.sent"] + v["bytes.rcvd"])] = key	  
      end
   end
end

--table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]

   if((key ~= nil) and (not(key == ""))) then
      value = stats_by_group_col[key]

      if(to_skip > 0) then
         to_skip = to_skip-1
      else
         if((num < perPage) or (all ~= nil))then
            if(num > 0) then
               print ",\n"
            end
            print_single_group(value)
            num = num + 1
         end
      end
      total = total + 1
   end
end -- for

if (as_n == nil and vlan_n == nil and network_n == nil and country_n == nil and os_n == nil) then -- single group info requested
   print ("\n], \"perPage\" : " .. perPage .. ",\n")
end

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

if (as_n == nil and vlan_n == nil and network_n == nil and country_n == nil and os_n == nil) then -- single group info requested
   print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
   print ("\"totalRows\" : " .. total .. " \n}")
end
