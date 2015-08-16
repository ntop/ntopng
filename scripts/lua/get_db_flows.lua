--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "db_utils"
require "template"

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)
ifstats = interface.getStats()

ifId = _GET["ifId"]
host = _GET["host"]
epoch = _GET["epoch"]
l7proto = _GET["l7proto"]

currentPage = _GET["currentPage"]
perPage = _GET["perPage"]
sortColumn = _GET["sortColumn"]
sortOrder = _GET["sortOrder"]

epoch_begin = _GET["epoch_begin"]
epoch_end = _GET["epoch_end"]

ip_version = _GET["version"]
if(ip_version == nil) then ip_version = "4" end

ip_version = tonumber(ip_version)

res = getInterfaceTopFlows(ifId, ip_version, (l7proto or ""), epoch_begin, epoch_end, (currentPage-1)*perPage, perPage, sortColumn or 'BYTES', sortOrder or 'DESC')

if((res == nil) or (type(res) == "string")) then
   return('{ "currentPage" : 1,  "data" : [], "perPage" : '..perPage..',  "sort" : [ [ "column_", "desc" ] ],"totalRows" : 0 }')
else      
   local rows = 0
   
   print('{ "currentPage" : '..currentPage..',  "data" : [\n')

   for _,flow in pairs(res) do
      local num = 0
      local base = "<A HREF='"..ntop.getHttpPrefix().."/lua/pro/db_explorer.lua?ifId="..ifId.."&epoch_begin="..epoch_begin.."&epoch_end="..epoch_end 

      if(flow["L4_SRC_PORT"] ~= nil) then
	 local base_host_url = base.."&host="
	 local base_port_url = base.."&port="
	 
	 client = ntop.getResolvedAddress(flow["IP_SRC_ADDR"])
	 server = ntop.getResolvedAddress(flow["IP_DST_ADDR"])

	 client = flow["IP_SRC_ADDR"]
	 server = flow["IP_DST_ADDR"]

	 if(ntop.isPro()) then
	    flow["CLIENT"] = base_host_url..flow["IP_SRC_ADDR"] .."'>"..client.."</A>:"..base_port_url..flow["L4_SRC_PORT"].."'>"..flow["L4_SRC_PORT"].."</A>"
	    flow["SERVER"] = base_host_url..flow["IP_DST_ADDR"] .."'>"..server.."</A>:"..base_port_url..flow["L4_DST_PORT"].."'>"..flow["L4_DST_PORT"].."</A>"	
	    flow["PROTOCOL"] = base.."&l4proto="..flow["PROTOCOL"].."'>"..l4ProtoToName(flow["PROTOCOL"]).."</A>"
	    flow["L7_PROTO"] = base.."&protocol="..flow["L7_PROTO"].."'>"..getApplicationLabel(interface.getnDPIProtoName(tonumber(flow["L7_PROTO"]))).."</A>"	    
	    flow["FLOW_URL"] = base.."&flow_idx="..flow["idx"].."'><span class='label label-info'>Info</span></A>"
	 else
	    flow["CLIENT"] = client..":"..flow["L4_SRC_PORT"]
	    flow["SERVER"] = server..":"..flow["L4_DST_PORT"]
	    flow["PROTOCOL"] = l4ProtoToName(flow["PROTOCOL"])
	    flow["L7_PROTO"] = getApplicationLabel(interface.getnDPIProtoName(tonumber(flow["L7_PROTO"])))     
	    flow["FLOW_URL"] = ""
	 end
      end

      flow["FIRST_SWITCHED"] = formatEpoch(tonumber(flow["FIRST_SWITCHED"]))
      flow["LAST_SWITCHED"] = formatEpoch(tonumber(flow["LAST_SWITCHED"]))

      -- flow["BYTES"] = bytesToSize(tonumber(flow["BYTES"]))
      -- flow["PACKETS"] = formatPackets(tonumber(flow["PACKETS"]))    

      if(rows > 0) then print(',\n') end

      for k,v in pairs(flow) do
	 if(num == 0) then print('{ ') else print(', ') end

	 print('"'..k..'": "'..v..'"')
	 num = num + 1
      end
      
      print('}')

      rows = rows + 1
   end  

   print('\n], "perPage" : '..perPage..',  "sort" : [ [ "'..sortColumn..'", "'.. sortOrder ..'" ] ], "totalRows" : '..rows..' }')
end


