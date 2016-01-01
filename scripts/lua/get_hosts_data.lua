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
protocol    = _GET["protocol"]
net         = _GET["net"]
long_names  = _GET["long_names"]

-- Host comparison parameters
mode        = _GET["mode"]
tracked     = _GET["tracked"]

-- Used when filtering by ASn, VLAN or network
asn          = _GET["asn"]
vlan         = _GET["vlan"]
network      = _GET["network"]
country      = _GET["country"]
os_    	     = _GET["os"]
antenna_mac  = _GET["antenna_mac"]
mac          = _GET["mac"]

-- table_id = _GET["table"]

function update_host_name(h)
   if(h["name"] == nil) then
      if(h["ip"] ~= nil) then
	 h["name"] = ntop.getResolvedAddress(h["ip"])
      else
	 h["name"] = h["mac"]
      end
   end

   return(h["name"])
end

-- Get from redis the throughput type bps or pps
throughput_type = getThroughputType()

if(long_names == nil) then
   long_names = false
else
   if(long_names == "1") then
      long_names = true
   else
      long_names = false
   end
end

if((sortColumn == nil) or (sortColumn == "column_"))then
   sortColumn = getDefaultTableSort("hosts")
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_hosts",sortColumn)
   end
end

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder("hosts")
else
   if((sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_order_hosts",sortOrder)
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

if(tracked ~= nil) then tracked = tonumber(tracked) else tracked = 0 end

if((mode == nil) or (mode == "")) then mode = "all" end

interface.select(ifname)

to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end
if((mac ~= nil) or (antenna_mac ~= nil)) then
   hosts_stats = interface.getLocalHostsInfo(false, sortColumn, perPage, to_skip, sOrder) -- false = little details
else  
   hosts_stats = interface.getHostsInfo(false, sortColumn, perPage, to_skip, sOrder) -- false = little details
end

hosts_stats,total = aggregateHostsStats(hosts_stats)
-- for k,v in pairs(hosts_stats) do io.write(k.." ["..sortColumn.."]\n") end

-- io.write("->"..total.." ["..sortColumn.."]\n")

if(all ~= nil) then
   perPage = 0
   currentPage = 0
end

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
num = 0

now = os.time()
vals = {}
num = 0

sort_mode = mode
-- for k,v in pairs(hosts_stats) do io.write(k.."\n") end

if(net ~= nil) then
   net = string.gsub(net, "_", "/")
end

if(mode == "network") then
   my_networks = { }
   for key, value in pairs(hosts_stats) do
      h = hosts_stats[key]
      nw_name = h["local_network_name"]

      if(h["local_network_name"] ~= nil) then
	 -- io.write(nw_name.."\n")

	 if(nw_name ~= nil) then
	    if(my_networks[nw_name] == nil) then
	       h["ip"] = nw_name
	       h["name"] = nw_name -- FIX

	       my_networks[nw_name] = h
	    else
	       my_networks[nw_name]["num_alerts"] = my_networks[nw_name]["num_alerts"] + h["num_alerts"]
	       my_networks[nw_name]["throughput_bps"] = my_networks[nw_name]["throughput_bps"] + h["throughput_bps"]
	       my_networks[nw_name]["throughput_pps"] = my_networks[nw_name]["throughput_pps"] + h["throughput_pps"]
	       my_networks[nw_name]["bytes.sent"] = my_networks[nw_name]["bytes.sent"] + h["bytes.sent"]
	       my_networks[nw_name]["bytes.rcvd"] = my_networks[nw_name]["bytes.rcvd"] + h["bytes.rcvd"]

	       if(my_networks[nw_name]["seen.first"] > h["seen.first"]) then
		  my_networks[nw_name]["seen.first"] = h["seen.first"]
	       end
	    end
	 end
      end
   end

   hosts_stats = my_networks
   mode = "local"
end


--
for key, value in pairs(hosts_stats) do
   num = num + 1
   postfix = string.format("0.%04u", num)
   ok = true

   if(not((mode == "all")
       or ((mode == "local") and (value["localhost"] == true))
    or ((mode == "remote") and (value["localhost"] ~= true)))) then
      ok = false
   end

   if(net ~= nil) then
      if((value["local_network_name"] == nil) or (value["local_network_name"] ~= net)) then
	 ok = false
      end
   end

   if(ok == true) then
      if(client ~= nil) then
	 ok = false

	 for k,v in pairs(hosts_stats[key]["contacts"]["client"]) do
	    --io.write(k.."\n")
	    if((ok == false) and (k == client)) then ok = true end
	 end

	 if(ok == false) then
	    for k,v in pairs(hosts_stats[key]["contacts"]["server"]) do
	       -- io.write(k.."\n")
	       if((ok == false) and (k == client)) then ok = true end
	    end
	 end
      else
	 ok = true
      end
   end

   if((protocol ~= nil) and (ok == true)) then
      info = interface.getHostInfo(key)

      if((info == nil) or (info["ndpi"][protocol] == nil)) then
	 ok = false
      end
   end

   if(ok) then
      --io.write("==>"..hosts_stats[key]["bytes.sent"].."[" .. sortColumn .. "]["..key.."]\n")

      if(sortColumn == "column_") then
	 vals[key] = key -- hosts_stats[key]["ipkey"]
	 elseif(sortColumn == "column_name") then
	 hosts_stats[key]["name"] = update_host_name(hosts_stats[key])
	 vals[hosts_stats[key]["name"]..postfix] = key
	 elseif(sortColumn == "column_since") then
	 vals[(now-hosts_stats[key]["seen.first"])+postfix] = key
	 elseif(sortColumn == "column_alerts") then
	 vals[(now-hosts_stats[key]["num_alerts"])+postfix] = key
	 elseif(sortColumn == "column_family") then
	 vals[(now-hosts_stats[key]["family"])+postfix] = key
	 elseif(sortColumn == "column_last") then
	 vals[(now-hosts_stats[key]["seen.last"]+1)+postfix] = key
	 elseif(sortColumn == "column_category") then
	 if(hosts_stats[key]["category"] == nil) then hosts_stats[key]["category"] = "" end
	 vals[hosts_stats[key]["category"]..postfix] = key
         elseif(sortColumn == "column_httpbl") then
	 if(hosts_stats[key]["httpbl"] == nil) then hosts_stats[key]["httpbl"] = "" end
	 vals[hosts_stats[key]["httpbl"]..postfix] = key
	 elseif(sortColumn == "column_asn") then
	 vals[hosts_stats[key]["asn"]..postfix] = key
	 elseif(sortColumn == "column_country") then
	 vals[hosts_stats[key]["country"]..postfix] = key
	 elseif(sortColumn == "column_vlan") then
	 vals[hosts_stats[key]["vlan"]..postfix] = key
	 elseif(sortColumn == "column_thpt") then
	 vals[hosts_stats[key]["throughput_"..throughput_type]+postfix] = key
	 elseif(sortColumn == "column_queries") then
	 vals[hosts_stats[key]["queries.rcvd"]+postfix] = key
	 elseif(sortColumn == "column_ip") then
	 vals[hosts_stats[key]["ipkey"]+postfix] = key
      else
	 -- io.write(key.."\n")
	 -- io.write(hosts_stats[key].."\n")
	 -- for k,v in pairs(hosts_stats[key]) do io.write(k.."\n") end

	 vals[(hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"])+postfix] = key
      end
   end
end

table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]

   if((key ~= nil) and (not(key == "")) and
((asn == nil) or (asn == tostring(hosts_stats[key]["asn"]))) and
((os_ == nil) or (os_ == tostring(hosts_stats[key]["os"]))) and
((country == nil) or (country == tostring(hosts_stats[key]["country"]))) and
((antenna_mac == nil) or (antenna_mac == tostring(hosts_stats[key]["antenna_mac"]))) and
((mac == nil) or (mac == tostring(hosts_stats[key]["mac"]))) and
((vlan == nil) or (vlan == tostring(hosts_stats[key]["vlan"]))) and
((network == nil) or (network == tostring(hosts_stats[key]["local_network_id"])))) then
      value = hosts_stats[key]

	 if((num < perPage) or (all ~= nil))then
	    if(num > 0) then print ",\n" end
	    print ('{ ')
	    print ('\"key\" : \"'..hostinfo2jqueryid(hosts_stats[key])..'\",')
	    
	    print ("\"column_ip\" : \"<A HREF='")

	    if(sort_mode == "network") then
	       url = nil
	       print(ntop.getHttpPrefix().."/lua/hosts_stats.lua?net=" ..string.gsub(hosts_stats[key]["ip"], "/", "_") .. "'>")
	    else
 	       url = ntop.getHttpPrefix().."/lua/host_details.lua?" ..hostinfo2url(hosts_stats[key])
	       print(url .. "'>")
	    end

	    print(mapOS2Icon(key))

	    print(" </A> ")

	    if(value["systemhost"] == true) then print("&nbsp;<i class='fa fa-flag'></i>") end

	    if((value["country"] ~= nil) and (value["country"] ~= "")) then
	       print("&nbsp;<a href=".. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country="..value["country"].."><img src='".. ntop.getHttpPrefix() .. "/img/blank.gif' class='flag flag-".. string.lower(value["country"]) .."'></a>")
	    end

            print("&nbsp;")
	    print(getOSIcon(value["os"]))

	    if(value["dump_host_traffic"] == true) then print("&nbsp;<i class='fa fa-hdd-o fa-lg'></i>") end

	    print("\", ")

            if(url ~= nil) then
	       print("\"column_url\" : \""..url.."\", ")
 	    end

	    print("\"column_name\" : \"")

	    if(value["name"] == nil) then 
	       value["name"] = ntop.getResolvedAddress(key)
	    end

	    if(value["name"] == "") then 
	       value["name"] = key
	    end
	    
	    if(long_names) then
      	       print(value["name"])
            else
	       print(shortHostName(value["name"]))	
	    end

	    if(value["ip"] ~= nil) then
	       label = getHostAltName(value["ip"])
	       if(label ~= value["ip"]) then
		  print (" ["..label.."]")
	       end
	    end

	    if((value["httpbl"] ~= nil) and (string.len(value["httpbl"]) > 2)) then
	       print (" <i class='fa fa-frown-o'></i>")
	    end

	    if((value["num_alerts"] ~= nil) and (value["num_alerts"] > 0)) then
	       print(" <i class='fa fa-warning fa-lg' style='color: #B94A48;'></i>")
	    end

	    --   print("</div>")

	    if((value["httpbl"] ~= nil) and (string.len(value["httpbl"]) > 2)) then print("\", \"column_httpbl\" : \"".. value["httpbl"]) end

	    if(value["vlan"] ~= nil) then

	       if(value["vlan"] ~= 0) then
		  print("\", \"column_vlan\" : "..value["vlan"])
	       else
		  print("\", \"column_vlan\" : \"0\"")
	       end

	    else
	       print("\", \"column_vlan\" : \"\"")
	    end

	    if(value["asn"] ~= nil) then
	       if(value["asn"] == 0) then
		  print(", \"column_asn\" : 0")
	       else
		  print(", \"column_asn\" : \"<A HREF=" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. value["asn"] ..">"..value["asname"].."</A>\"")
	       end
	    end

	    
	    print(", \"column_since\" : \"" .. secondsToTime(now-value["seen.first"]+1) .. "\", ")
	    print("\"column_last\" : \"" .. secondsToTime(now-value["seen.last"]+1) .. "\", ")

	    if((value["throughput_trend_"..throughput_type] ~= nil) and
	       (value["throughput_trend_"..throughput_type] > 0)) then

	       if(throughput_type == "pps") then
		  print ("\"column_thpt\" : \"" .. pktsToSize(value["throughput_pps"]).. " ")
	       else
		  print ("\"column_thpt\" : \"" .. bitsToSize(8*value["throughput_bps"]).. " ")
	       end

	       if(value["throughput_trend_"..throughput_type] == 1) then
		  print("<i class='fa fa-arrow-up'></i>")
		  elseif(value["throughput_trend_"..throughput_type] == 2) then
		  print("<i class='fa fa-arrow-down'></i>")
		  elseif(value["throughput_trend_"..throughput_type] == 3) then
		  print("<i class='fa fa-minus'></i>")
	       end

	       print("\",")
	    else
	       print ("\"column_thpt\" : \"0 "..throughput_type.."\",")
	    end

	    print("\"column_traffic\" : \"" .. bytesToSize(value["bytes.sent"]+value["bytes.rcvd"]))

	    print ("\", \"column_alerts\" : \"")
	    if((value["num_alerts"] ~= nil) and (value["num_alerts"] > 0)) then
	       print(""..value["num_alerts"])
	    else
	       print("0")
	    end
	    if(value["localhost"] ~= nil) then
	       print ("\", \"column_location\" : \"")
	       if(value["localhost"] == true) then print("<span class='label label-success'>Local</span>") else print("<span class='label label-default'>Remote</span>") end
	    end

	    sent2rcvd = round((value["bytes.sent"] * 100) / (value["bytes.sent"]+value["bytes.rcvd"]), 0)
	    print ("\", \"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
		   .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>")

	    print("\" } ")
	    num = num + 1
      end
   end
end -- for

print ("\n], \"perPage\" : " .. perPage .. ",\n")

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
print ("\"totalRows\" : " .. total .. " \n}")
