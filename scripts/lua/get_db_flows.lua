--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"
require "db_utils"
require "flow_aggregation_utils"
require "template"

interface.select(ifname)
ifstats = interface.getStats()

local ifId = _GET["ifid"]
local host = _GET["peer1"]
local peer = _GET["peer2"]
local vlan = _GET["vlan"]
local epoch = _GET["epoch"]
local l7proto = _GET["l7proto"]
if l7proto == nil or l7proto == "" then
   l7proto = _GET["l7_proto_id"]
end

local currentPage = _GET["currentPage"]
local perPage = _GET["perPage"]
local sortColumn = _GET["sortColumn"]
local sortOrder = _GET["sortOrder"]

local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]

local l4proto = _GET["l4proto"]
if l4proto == nil or l4proto == "" then
   l4proto = _GET["l4_proto_id"]
end
local port = _GET["port"]
local info = _GET["info"]
local vlan = _GET["vlan"]
local profile = _GET["profile"]
local limit = _GET["limit"]

local format = _GET["format"]
if(format == nil) then format = "json" end

local ip_version = _GET["version"]
if(ip_version == nil) then ip_version = "4" end

local ip_version = tonumber(ip_version)

if((currentPage == nil) or (currentPage == "")) then currentPage = 1 end
if((perPage == nil) or (perPage == "")) then perPage = 5 end
if((sortOrder == nil) or (sortOrder == "")) then sortOrder = "asc" end
if((sortColumn == nil) or (sortColumn == "")) then sortColumn = "BYTES" end

if(format == "txt") then
   limit = 1000
   currentPage = 1
   perPage = limit
else
   if limit == nil then
      -- when flow aggregation is used, requests can be made with a nil limit so it is important to re-calculate it
      local count = getNumFlows(ifId, ip_version, host, (l4proto or ""), (port or ""), (l7proto or ""), (info or ""),
				(vlan or ""), (profile or ""),
				epoch_begin, epoch_end,
				true --[[ force count from the raw flows table --]],
				true --[[ enforce allowed networks when counting --]])
      if count ~= nil and count[1] ~= nil then
	 limit = count[1]["TOT_FLOWS"]
      end
   end
end

res = getInterfaceTopFlows(ifId, ip_version, host, peer, (l7proto or ""), (l4proto or ""), (port or ""),
			   vlan, (profile or ''), (info or ""),
			   epoch_begin, epoch_end, (currentPage-1)*perPage, perPage, sortColumn or 'BYTES', sortOrder or 'DESC')

if(format == "txt") then
   -- TXT
   local filename="ntopng_flows"
   if ip_version ~= nil and ip_version ~= "" then filename = filename.."_IPv"..ip_version end
   if host ~= nil and host ~= "" then filename = filename .."_host_"..getPathFromKey(host) end
   if l4proto ~= nil and l4proto ~="" then filename = filename .."_l4proto_"..l4ProtoToName(l4proto) end
   if l7proto ~= nil and l7proto ~= "" then
      local protos = {}
      for proto_name, proto_id in pairs(interface.getnDPIProtocols()) do
	 protos[proto_id] = proto_name
      end
      local l7proto_label = l4proto
      if protos[l7proto] ~= nil then l7proto_label = protos[l7proto] end
      filename = filename .."_l7proto_"..l7proto_label
   end
   if port ~= nil and port ~= "" then filename = filename .."_port_"..tostring(port) end
   if epoch_begin ~= nil and epoch_begin ~= "" then
      filename = filename.."_from_"..string.gsub(formatEpoch(epoch_begin), ' ', '-')
   end
   if epoch_end ~= nil and epoch_begin ~= "" then
      filename = filename.."_to_"..string.gsub(formatEpoch(epoch_end), ' ', '-')
   end
   filename = filename..".txt"
   sendHTTPContentTypeHeader('text/plain', 'attachment; filename="'..filename..'"')
   local num = 0
   for _,flow in pairs(res) do
      if(num == 0) then
	 local elems = 0

	 print("# ")
	 for k,v in pairs(flow) do
	    if(elems > 0) then print("|") end
	       print(k)
	       elems = elems + 1
	    end

	 print("\n")
      end

      local elems = 0
      for k,v in pairs(flow) do
	 if(elems > 0) then print("|") end

	 if(k == "PROTOCOL") then print(l4ProtoToName(v))
	 elseif(k == "L7_PROTO") then print(interface.getnDPIProtoName(tonumber(v)))
	 else
	    print(v)
	 end
	 elems = elems + 1
      end

      print("\n")
      num = num + 1
   end
else
   sendHTTPContentTypeHeader('text/html')
   -- JSON
   if((res == nil) or (type(res) == "string")) then
      return('{ "currentPage" : 1,  "data" : [], "perPage" : '..perPage..',  "sort" : [ [ "column_", "desc" ] ],"totalRows" : 0 }')
   else
      local rows = 0

      print('{ "currentPage" : '..currentPage..',  "data" : [\n')

      for _,flow in pairs(res) do
	 local num = 0
	 local base = "<A HREF='"..ntop.getHttpPrefix().."/lua/pro/db_explorer.lua?search_flows=true&ifid="..ifId.."&epoch_begin="..epoch_begin.."&epoch_end="..epoch_end.."&search="
	 if not isEmptyString(flow["VLAN_ID"]) and tonumber(flow["VLAN_ID"]) > 0 then
	    base = base.."&vlan="..flow["VLAN_ID"]
	 end

	 if(flow["L4_SRC_PORT"] ~= nil) then
	    local base_host_url = base.."&l4proto=&port=&host="
	    local base_port_url = base.."&l4proto=&host=&port="
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

	       if((sport ~= nil) and (sport ~= "0")) then
		  flow["CLIENT"] = flow["CLIENT"] .. ":"..base_port_url..flow["L4_SRC_PORT"].."'>"..sport.."</A>"
	       end
	       if((dport ~= nil) and (dport ~= "0")) then
		  flow["SERVER"] = flow["SERVER"] .. ":"..base_port_url..flow["L4_DST_PORT"].."'>"..dport.."</A>"
	       end

	       flow["INFO"] = base.."&l4proto=&port=&host=&info="..flow["INFO"].."'><span title='"..flow["INFO"].."'>"..shortenString(flow["INFO"]).."</span></A>"

	       flow["PROTOCOL"] = base.."&protocol=&port=&host=&l4proto="..flow["PROTOCOL"].."'>"..pname.."</A>"
	       flow["L7_PROTO"] = base.."&port=&host=&l4proto=&protocol="..flow["L7_PROTO"].."'>"..getApplicationLabel(interface.getnDPIProtoName(tonumber(flow["L7_PROTO"]))).."</A>"
	       flow["FLOW_URL"] = base.."&row_id="..flow["idx"].."&version="..ip_version.."'><span class='label label-info'>Info</span></A>"

	       if flow["PROFILE"] ~= nil and flow["PROFILE"] ~="" then
		  flow["INFO"] = "<span class='label label-primary'>"..flow["PROFILE"].."</span>&nbsp;"..flow["INFO"]
	       end

	    else
	       flow["CLIENT"] = client..":"..ntop.getservbyport(tonumber(flow["L4_SRC_PORT"]), lower_pname)
	       flow["SERVER"] = server..":"..ntop.getservbyport(tonumber(flow["L4_DST_PORT"]), lower_pname)
	       flow["PROTOCOL"] = pname
	       flow["L7_PROTO"] = getApplicationLabel(interface.getnDPIProtoName(tonumber(flow["L7_PROTO"])))
	       flow["FLOW_URL"] = ""
	       flow["INFO"] = "<span title='"..flow["INFO"].."'>"..shortenString(flow["INFO"]).."</span>"
	    end
	 end

	 for _, k in pairs({"CLIENT", "SERVER", "PROTOCOL", "L7_PROTO"}) do
	    flow[k] = "<i>"..flow[k].."</i>"
	 end

	 duration = tonumber(flow["LAST_SWITCHED"])-tonumber(flow["FIRST_SWITCHED"])+1
	 flow["AVG_THROUGHPUT"] = bitsToSize((8*tonumber(flow["BYTES"])) / duration)

	 flow["FIRST_SWITCHED"] = formatEpoch(tonumber(flow["FIRST_SWITCHED"]))
	 flow["LAST_SWITCHED"] = formatEpoch(tonumber(flow["LAST_SWITCHED"]))

	 flow["BYTES"] = bytesToSize(tonumber(flow["BYTES"]))
	 flow["IN_BYTES"] = bytesToSize(tonumber(flow["IN_BYTES"]))
	 flow["OUT_BYTES"] = bytesToSize(tonumber(flow["OUT_BYTES"]))
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
end
