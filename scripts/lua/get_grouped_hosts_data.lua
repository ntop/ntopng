--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local host_pools_utils = require "host_pools_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

-- Table parameters
all = _GET["all"]
currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]

group_col   = _GET["grouped_by"]
as_n        = _GET["asn"]
vlan_n      = _GET["vlan"]
network_n   = _GET["network"]
country_n   = _GET["country"]
os_n        = _GET["os"]
pool_n      = _GET["pool"]
ipver_n     = _GET["version"]

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

to_skip = (currentPage-1) * perPage

if (all ~= nil) then
   perPage = 0
   currentPage = 0
end

if (as_n == nil and vlan_n == nil and network_n == nil and country_n == nil and os_n == nil and pool_n == nil) then -- single group info requested
   print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
end
num = 0
total = 0

now = os.time()
vals = {}

stats_by_group_col = {}

interface.select(ifname)
stats_by_group_key = interface.getGroupedHosts(false, "column_"..group_col, country_n, os_n, tonumber(vlan_n), tonumber(as_n), tonumber(network_n), true, tonumber(pool_n), tonumber(ipver_n)) -- false = little details)
stats_by_group_col = stats_by_group_key

--[[
Prepares a json containing table data, together with HTML.
--]]

function print_single_group(value)
   print ('{ ')
   print ('\"key\" : \"'..value["id"]..'\",')

   print ("\"column_id\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/")
   if (group_col == "asn" or as_n ~= nil) then
      print("hosts_stats.lua?asn=" ..tostring(value["id"]) .. "'>")
   elseif (group_col == "vlan" or vlan_n ~= nil) then
      print("hosts_stats.lua?vlan="..value["id"].."'>")
   elseif (group_col == "country" or country_n ~= nil) then
      print("hosts_stats.lua?country="..value["id"].."'>")
      print(getFlag(value["country"]).."&nbsp&nbsp")
   elseif (group_col == "os" or os_n ~= nil) then        
      print("hosts_stats.lua?os=".. string.gsub(value["id"], " ", '%%20')  .."'>")
      if(value["id"] ~= nil ) then
	 print("".. getOSIcon(value["id"]) .."")
      end      
   elseif (group_col == "local_network_id" or group_col == "local_network" or network_n ~= nil) then
      print("hosts_stats.lua?network="..tostring(value["id"]))
      if not isEmptyString(ipver_n) then print("&version="..ipver_n) end
      print("'>")
   elseif (group_col == "pool_id" or pool_n ~= nil) then
      print("hosts_stats.lua?pool="..tostring(value["id"]).."'>")
   elseif (group_col == "mac") then
      print("hosts_stats.lua?mac="..value["name"].."'>")
   else
      print("hosts_stats.lua'>")
   end

   if (group_col == "local_network_id" or group_col == "local_network" or network_n ~= nil) then
      print(value["name"]..'</A> ')
      print('", "column_chart": "')
      if tonumber(value["id"]) ~= -1 and interface.isPcapDumpInterface() == false then
	 print('<A HREF=\''..ntop.getHttpPrefix()..'/lua/network_details.lua?network='..value["id"]..'&page=historical\'><i class=\'fa fa-area-chart fa-lg\'></i></A>')
      else
	 print("-")
      end
      print('", ')

   elseif group_col == "vlan" or vlan_n ~= nil then
      print(value["id"]..'</A> ')
      print('", "column_chart": "')
      if value["id"] ~= "0" then
	 print('<A HREF=\''..ntop.getHttpPrefix()..'/lua/vlan_details.lua?vlan='..value["id"]..'&page=historical\'><i class=\'fa fa-area-chart fa-lg\'></i></A>')
      end
      print('", ')

   elseif(group_col == "mac") then
      manufacturer = get_manufacturer_mac(value["name"])
      if(manufacturer == nil) then manufacturer = "" end
      print(manufacturer..'</A>", ')
   elseif(group_col == "pool_id") then
      local pool_name = host_pools_utils.getPoolName(getInterfaceId(ifname), tostring(value["id"]))
      print(pool_name..'</A> " , ')

      if tostring(value["id"]) ~= host_pools_utils.DEFAULT_POOL_ID then
         print('"column_chart": "')
         print('<A HREF='..ntop.getHttpPrefix()..'/lua/pool_details.lua?pool='..value["id"]..'&page=historical><i class=\'fa fa-area-chart fa-lg\'></i></A>')
         print('", ')
      end
   elseif(group_col == "country" and value["id"] == "Uncategorized") then
      print('</A>'..value["id"]..'", ')
   else
      print(value["id"]..'</A>", ')
   end

   local alt = getHostAltName(value["id"])
   
   if((alt ~= nil) and (alt ~= value["id"])) then alt = " ("..alt..")" else alt = "" end
   print('"column_link": "<A HREF=\''..ntop.getHttpPrefix()..'/lua/mac_details.lua?mac='.. value["id"] ..'\'>'.. value["id"]..alt..'</A>')

   if(not(isSpecialMac(value["id"]))) then
        local icon = getHostIcon(value["id"])

	if(icon ~= "") then
	   print(icon)
        end
   end

   print('",')

   if(group_col == "mac") then
     print('"column_manufacturer": "'..manufacturer..'",')
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
      print("\"column_name\" : \""..printASN(value["id"], value["name"]))
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
   as_val = stats_by_group_col[tonumber(as_n)]
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
   vlan_val = stats_by_group_col[tonumber(vlan_n)]
   if (vlan_val == nil) then
      print('{}')
   else
      print_single_group(vlan_val)
   end
   stats_by_group_col = {}
elseif (network_n ~= nil) then
   network_val = stats_by_group_col[tonumber(network_n)]
   if (network_val == nil) then
      print('{}')
   else
      print_single_group(network_val)
   end
   stats_by_group_col = {}
elseif (pool_n ~= nil) then
   pool_val = stats_by_group_col[tonumber(pool_n)]
   if (pool_val == nil) then
      print('{}')
   else
      print_single_group(pool_val)
   end
   stats_by_group_col = {}
end

vals = { } 
for key,value in pairs(stats_by_group_col) do
   v = stats_by_group_col[key]    
   if((key ~= nil) and (v ~= nil)) then
      if(sortColumn == "column_id") then
	 vals[key] = v["id"]
      elseif(sortColumn == "column_name") then
	 vals[key] = v["name"]
      elseif(sortColumn == "column_hosts") then
	 vals[key] = v["num_hosts"]
      elseif(sortColumn == "column_since") then
	 vals[key] = (now-v["seen.first"])
      elseif(sortColumn == "column_alerts") then
	 vals[key] = (now-v["num_alerts"])
      elseif(sortColumn == "column_last") then
	 vals[key] = (now-stats_by_group_key[col]["seen.last"]+1)
      elseif(sortColumn == "column_thpt") then
	 vals[key] = v["throughput_"..throughput_type]
      elseif(sortColumn == "column_queries") then
	 vals[key] = v["queries.rcvd"]
      elseif(sortColumn == "column_manufacturer") then
         local m = get_manufacturer_mac(key)
	 vals[key] = m
      else
	 vals[key] = (v["bytes.sent"] + v["bytes.rcvd"])
      end
   end
end

--table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

local iterator
if sortColumn == "column_id" then
   -- Sort for this column is already provided by C, only the sort order can be reversed here
   iterator = pairsByKeys
else
   -- We provide our own sort
   iterator = pairsByValues
end

num = 0
for _key, _val in iterator(vals, funct) do
   value = stats_by_group_col[_key]

   -- e.g. this is empty for hosts without a country
   if not isEmptyString(value["id"]) then
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

if (as_n == nil and vlan_n == nil and network_n == nil and country_n == nil and os_n == nil and pool_n == nil) then -- single group info requested
   print ("\n], \"perPage\" : " .. perPage .. ",\n")
end

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

if (as_n == nil and vlan_n == nil and network_n == nil and country_n == nil and os_n == nil and pool_n == nil) then -- single group info requested
   print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
   print ("\"totalRows\" : " .. total .. " \n}")
end
