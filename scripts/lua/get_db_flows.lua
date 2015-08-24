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

l4proto = _GET["l4proto"]
port = _GET["port"]
limit = _GET["limit"]

ip_version = _GET["version"]
if(ip_version == nil) then ip_version = "4" end

ip_version = tonumber(ip_version)

if((currentPage == nil) or (currentPage == "")) then currentPage = 1 end
if((perPage == nil) or (perPage == "")) then perPage = 5 end
if((sortOrder == nil) or (sortOrder == "")) then sortOrder = "asc" end
if((sortColumn == nil) or (sortColumn == "")) then sortColumn = "BYTES" end

res = getInterfaceTopFlows(ifId, ip_version, host, (l7proto or ""), (l4proto or ""), (port or ""), epoch_begin, epoch_end, (currentPage-1)*perPage, perPage, sortColumn or 'BYTES', sortOrder or 'DESC', limit)

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
	 local pname = l4ProtoToName(flow["PROTOCOL"])
	 local lower_pname = string.lower(pname)
	 
	 client = shortenString(host2name(flow["IP_SRC_ADDR"], flow["VLAN_ID"]))
	 server = shortenString(host2name(flow["IP_DST_ADDR"], flow["VLAN_ID"]))

	 --client = flow["IP_SRC_ADDR"]
	 --server = flow["IP_DST_ADDR"]

	 if(ntop.isPro()) then
	    local sport = ntop.getservbyport(tonumber(flow["L4_SRC_PORT"]), lower_pname)
	    local dport = ntop.getservbyport(tonumber(flow["L4_DST_PORT"]), lower_pname)

	    flow["CLIENT"] = base_host_url..flow["IP_SRC_ADDR"] .."'>"..client.."</A>"
	    flow["SERVER"] = base_host_url..flow["IP_DST_ADDR"] .."'>"..server.."</A>"

	    if((sport ~= nil) and (sport ~= "0")) then flow["CLIENT"] = flow["CLIENT"] .. ":"..base_port_url..flow["L4_SRC_PORT"].."'>"..sport.."</A>" end
	    if((dport ~= nil) and (dport ~= "0")) then flow["SERVER"] = flow["SERVER"] .. ":"..base_port_url..flow["L4_DST_PORT"].."'>"..dport.."</A>" end
	       

	    flow["PROTOCOL"] = base.."&l4proto="..flow["PROTOCOL"].."'>"..pname.."</A>"
	    flow["L7_PROTO"] = base.."&protocol="..flow["L7_PROTO"].."'>"..getApplicationLabel(interface.getnDPIProtoName(tonumber(flow["L7_PROTO"]))).."</A>"	    
	    flow["FLOW_URL"] = base.."&flow_idx="..flow["idx"].."&version="..ip_version.."'><span class='label label-info'>Info</span></A>"
	 else
	    flow["CLIENT"] = client..":"..ntop.getservbyport(flow["L4_SRC_PORT"], lower_pname)
	    flow["SERVER"] = server..":"..ntop.getservbyport(flow["L4_DST_PORT"], lower_pname)
	    flow["PROTOCOL"] = pname
	    flow["L7_PROTO"] = getApplicationLabel(interface.getnDPIProtoName(tonumber(flow["L7_PROTO"])))     
	    flow["FLOW_URL"] = ""
	 end
      end

      duration = tonumber(flow["LAST_SWITCHED"])-tonumber(flow["FIRST_SWITCHED"])+1
      flow["AVG_THROUGHPUT"] = bitsToSize((8*tonumber(flow["BYTES"])) / duration)

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

   if(limit == nil) then limit = rows end
   print('\n], "perPage" : '..perPage..',  "sort" : [ [ "'..sortColumn..'", "'.. sortOrder ..'" ] ], "totalRows" : '..limit..' }')
end


