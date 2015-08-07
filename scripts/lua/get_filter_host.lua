--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

-- Table parameters
all = _GET["all"]
host        = _GET["host"]
vlan        = _GET["vlan"]
key         = _GET["key"]

-- table_id = _GET["table"]

if (vlan == nil) then vlan = 0 end

if((sortColumn == nil) or (sortColumn == "column_")) then
   sortColumn = getDefaultTableSort("http_hosts")
else
   if((sortColumn ~= "column_") and (sortColumn ~= "")) then
      tablePreferences("sort_http_hosts", sortColumn)
   end
end

--io.write(sortColumn.."\n")

if(sortOrder == nil) then
   sortOrder = getDefaultTableSortOrder("http_hosts")
else
   if(sortColumn ~= "column_") and (sortColumn ~= "")) then
      tablePreferences("sort_order_http_hosts",sortOrder)
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

hosts_stats = interface.listHTTPhosts(nil)
if (host == nil) then
  flows_stats = interface.queryFlowsInfo("SELECT * FROM FLOWS")
else
  flows_stats = interface.queryFlowsInfo("SELECT * FROM FLOWS WHERE host = "..host.." AND vlan = "..vlan)
end

to_skip = (currentPage-1) * perPage

if(all ~= nil) then
   perPage = 0
   currentPage = 0
end

if ( key == nil ) then
		print("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
		num = 0
		total = 0

		now = os.time()
		vals = {}
		num = 0

		sort_mode = mode

		--
		for key, value in pairs(hosts_stats) do
			num = num + 1
			postfix = string.format("0.%04u", num)
			ok = true

			if(sortColumn == "column_http_virtual_host") then
				vals[key] = key
				elseif(sortColumn == "column_server_ip") then
				vals[hosts_stats[key]["server.ip"]..postfix] = key
				elseif(sortColumn == "column_bytes_sent") then
				vals[hosts_stats[key]["bytes.sent"]+postfix] = key
				elseif(sortColumn == "column_bytes_rcvd") then
				vals[hosts_stats[key]["bytes.rcvd"]+postfix] = key
				elseif(sortColumn == "column_http_requests") then
				vals[hosts_stats[key]["http.requests"]+postfix] = key
				else 
				vals[hosts_stats[key]["http.act_num_requests"]+postfix] = key
			end
		end

		table.sort(vals)


		if(sortOrder == "asc") then
			funct = asc
		else
			funct = rev
		end

		num = 0

		tempTable = {}
		for _key, _value in pairs(flows_stats) do
			 if ( flows_stats[_key]["srv.ip"] == host ) then
					cli = flows_stats[_key]["cli.ip"]
					tempTable[cli] = {}
					tempTable[cli]["server"] = flows_stats[_key]["srv.ip"]
					tempTable[cli]["duration"] = flows_stats[_key]["duration"]
					tempTable[cli]["bytesRcvd"] = flows_stats[_key]["srv2cli.bytes"]
					tempTable[cli]["bytesSent"]=  flows_stats[_key]["cli2srv.bytes"]
					tempTable[cli]["proto"] = flows_stats[_key]["proto.ndpi"]				
			 end
		end -- for

		num = 0
		for _key, _value in pairs(tempTable) do
			 if(to_skip > 0) then
				to_skip = to_skip-1
			 else
				 if((num < perPage) or (all ~= nil)) then
					 if(num > 0) then print ",\n" end
					 print('{ ')
					


					 print('\"key\" : \"'.. _key ..'\",\n')
					 --print(" \"column_http_virtual_host\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/flow_details.lua?host_details=".._key.."</A>,\"\n")
					  print(" \"column_http_virtual_host\" : \"<A HREF='")
						url = ntop.getHttpPrefix().."/lua/host_details.lua?" ..hostinfo2url(_key)
					 print(url.."'>")
					 print(_key)
				  print("</A>\"")
					 
					 print(", \"column_server_ip\" : \"<A HREF='")
						url = ntop.getHttpPrefix().."/lua/filter_to_host.lua?" ..hostinfo2url(host)
					 print(url.."'>")
					 print(host)
				  print("</A>\"")

				
					 print(",\n \"column_duration\" : \"" .. secondsToTime(tempTable[_key]["duration"]).."\"")
					 print(",\n \"column_proto\" : \"" .. (tempTable[_key]["proto"]).."\"")
					 print(",\n \"column_bytes_sent\" : \"" .. bytesToSize(tempTable[_key]["bytesSent"]))
					 print("\",\n \"column_bytes_rcvd\" : \"" .. bytesToSize(tempTable[_key]["bytesRcvd"]))
					 
					 --print("\",\n \"column_http_requests\" : \"" .. formatValue(value["http.requests"]))
					 --print("\",\n \"column_act_num_http_requests\" : \"" .. formatValue(value["http.act_num_requests"]).." ")
					-- if(value["http.requests_trend"] == 1) then
						 --print("<i class='fa fa-arrow-up'></i>")
					 --elseif(value["http.requests_trend"] == 2) then
						 --print("<i class='fa fa-arrow-down'></i>")
					 --else
						 --print("<i class='fa fa-minus'></i>")
					 --end
					 print("\" } ")
					 num = num + 1
				 end	
			 end

				total = total + 1
		end -- for

		print("\n], \"perPage\" : " .. perPage .. ",\n")

		if(sortColumn == nil) then
			sortColumn = ""
		end

		if(sortOrder == nil) then
			sortOrder = ""
		end

		print("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
		print("\"totalRows\" : " .. total .. " \n}")
else
		flows_stats = interface.getFlowsInfo(nil)	
		tempTable = {}
		c = 0
		for _key, _value in pairs(flows_stats) do
			
			 --io.write ( "@@@@@" ..host .."###"..flows_stats[_key]["srv.ip"].."###"..flows_stats[_key]["srv.ip"].."\n")
			 if ( flows_stats[_key]["srv.ip"] == host and key == flows_stats[_key]["cli.ip"] ) then			
						cli = flows_stats[_key]["cli.ip"]
						tempTable[cli] = {}
						tempTable[cli]["server"] = flows_stats[_key]["srv.ip"]
						tempTable[cli]["duration"] = flows_stats[_key]["duration"]
						tempTable[cli]["bytesRcvd"] = flows_stats[_key]["srv2cli.bytes"]
						tempTable[cli]["bytesSent"]=  flows_stats[_key]["cli2srv.bytes"]
						tempTable[cli]["proto"] = flows_stats[_key]["proto.ndpi"]
			 end
			 --io.write (  c .. "\n")
		end -- for
		for k, v in pairs ( tempTable ) do
			--io.write ( "@@@@@@@@@@@@¸\n")
				 print ("{")
				 print("\n \"column_duration\" : \"" .. secondsToTime(tempTable[k]["duration"]).."\"")
				 print(",\n \"column_bytes_sent\" : \"" .. bytesToSize(tempTable[k]["bytesSent"]))
				 print("\",\n \"column_bytes_rcvd\" : \"" .. bytesToSize(tempTable[k]["bytesRcvd"]))
				 print ("\"\n}")
			 end
		

end
