--
-- (C) 2013-16 - ntop.org
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
criteria    = _GET["criteria"]

-- Host comparison parameters
mode        = _GET["mode"]
tracked     = _GET["tracked"]

-- Used when filtering by ASn, VLAN or network
asn          = _GET["asn"]
vlan         = _GET["vlan"]
network      = _GET["network"]
country      = _GET["country"]
os_    	     = _GET["os"]
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

criteria_key = nil
sortPrefs = "hosts"
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

if(tracked ~= nil) then tracked = tonumber(tracked) else tracked = 0 end

if((mode == nil) or (mode == "")) then mode = "all" end

interface.select(ifname)

to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end

hosts_retrv_function = interface.getHostsInfo
if mode == "local" then
   hosts_retrv_function = interface.getLocalHostsInfo
elseif mode == "remote" then
   hosts_retrv_function = interface.getRemoteHostsInfo
end

hosts_stats = hosts_retrv_function(false, sortColumn, perPage, to_skip, sOrder,
	                           country, os_, tonumber(vlan), tonumber(asn),
				   tonumber(network), mac) -- false = little details
--io.write("hello\n")
--tprint(hosts_stats)
--io.write("---\n")
if(hosts_stats == nil) then total = 0 else total = hosts_stats["numHosts"] end
hosts_stats = hosts_stats["hosts"]
-- for k,v in pairs(hosts_stats) do io.write(k.." ["..sortColumn.."]\n") end


if(all ~= nil) then
   perPage = 0
   currentPage = 0
end

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")

now = os.time()
vals = {}

num = 0
if(hosts_stats ~= nil) then
   for key, value in pairs(hosts_stats) do
      num = num + 1
      postfix = string.format("0.%04u", num)

      --[[
	 if((protocol ~= nil) and (ok == true)) then
	 info = interface.getHostInfo(key)

	 if((info == nil) or (info["ndpi"][protocol] == nil)) then
	 ok = false
	 end
	 end
      --]]


      -- io.write("==>"..key.."\n")
      -- tprint(hosts_stats[key])
      -- io.write("==>"..hosts_stats[key]["bytes.sent"].."[" .. sortColumn .. "]["..key.."]\n")

      if(sortColumn == "column_") then
	 vals[key] = key -- hosts_stats[key]["ipkey"]
      elseif(sortColumn == "column_name") then
	 hosts_stats[key]["name"] = update_host_name(hosts_stats[key])
	 vals[hosts_stats[key]["name"]..postfix] = key
      elseif(sortColumn == "column_since") then
	 vals[(now-hosts_stats[key]["seen.first"])+postfix] = key
      elseif(sortColumn == "column_alerts") then
	 vals[hosts_stats[key]["num_alerts"]+postfix] = key
	 -- print("["..key.."=".. hosts_stats[key]["num_alerts"].."]\n")
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
	       --io.write(key.."="..hosts_stats[key]["criteria"][criteria_key].."\n")
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

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]

   value = hosts_stats[key]

   if(num > 0) then print ",\n" end
   print ('{ ')
   symkey = hostinfo2jqueryid(hosts_stats[key])
   print ('\"key\" : \"'..symkey..'\",')

   print ("\"column_ip\" : \"<A HREF='")
   url = ntop.getHttpPrefix().."/lua/host_details.lua?" ..hostinfo2url(hosts_stats[key])
   print(url .. "'>")
   print(mapOS2Icon(key))
   print(" </A> ")

   if(value["systemhost"] == true) then print("&nbsp;<i class='fa fa-flag'></i>") end

   if((value["country"] ~= nil) and (value["country"] ~= "")) then
      print("&nbsp;<a href=".. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?country="..value["country"].."><img src='".. ntop.getHttpPrefix() .. "/img/blank.gif' class='flag flag-".. string.lower(value["country"]) .."'></a>")
   end

   print("&nbsp;")

   local icon = getOSIcon(value["os"])
   if(mac ~= nil and trimSpace(getOSIcon(value["os"])) ~= trimSpace(getHostIcon(hosts_stats[key]["mac"]))) then
      icon = icon.."&nbsp;"..getHostIcon(hosts_stats[key]["mac"])
   end
   if(icon == "") then icon = getHostIcon(hosts_stats[key]["ip"].."@"..hosts_stats[key]["vlan"]) end
   print(icon)

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


   if((criteria_key ~= nil) and (value["criteria"] ~= nil)) then
      print("\"column_"..criteria.."\" : \"" .. criteria_format(value["criteria"][criteria_key]) .. "\", ")
   end

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
   -- io.write("-------------------------\n")
   -- tprint(value)
   if(value["localhost"] ~= nil or value["systemhost"] ~= nil) then
      print ("\", \"column_location\" : \"")
      if value["localhost"] == true --[[or value["systemhost"] == true --]] then
	 print("<span class='label label-success'>Local Host</span>") else print("<span class='label label-default'>Remote Host</span>")
      end
      if value["is_blacklisted"] == true then
	 print(" <span class='label label-danger'>Blacklisted Host</span>")
      end
   end

   sent2rcvd = round((value["bytes.sent"] * 100) / (value["bytes.sent"]+value["bytes.rcvd"]), 0)
   print ("\", \"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
	     .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>")

   print("\" } ")
   num = num + 1
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
