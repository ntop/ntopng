--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

local ifId        = _GET["ifId"]
local ip_version  = _GET["version"]
local host        = _GET["host"]
local epoch_begin = _GET["epoch_begin"]
local epoch_end   = _GET["epoch_end"]
local l4proto     = _GET["l4proto"]
local l7proto     = _GET["l7proto"]
local profile     = _GET["profile"]
local port        = _GET["port"]
local info        = _GET["info"]
local limit       = _GET["limit"]
local format      = _GET["format"]
local action      = _GET["action"]

if(ip_version == nil) then ip_version = "4" end
ip_version = tonumber(ip_version)

function top_peers_query(interface_id, version, host, protocol, port, l7proto, info, begin_epoch, end_epoch)
   if(host == nil or host == "") then return nil end
   if(version == nil) then version = 4 end

   if(info == "") then info = nil end
   if(l7proto == "") then l7proto = nil end
   if(protocol == "") then protocol = nil end

   sql = " SELECT "
   if(version == 4) then
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN INET_NTOA(IP_DST_ADDR) ELSE INET_NTOA(IP_SRC_ADDR) END peer, "
   else
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IP_DST_ADDR ELSE IP_SRC_ADDR END peer, "
   end

   sql = sql.."BYTES as bytes, PACKETS as packets, PROTOCOL as l4proto, L7_PROTO as l7proto, "
   sql = sql.."FIRST_SWITCHED as first_switched, LAST_SWITCHED as last_switched "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if((l7proto ~= nil) and (l7proto ~= "")) then sql = sql .." AND L7_PROTO="..l7proto end
   if((protocol ~= nil) and (protocol ~= "")) then sql = sql .." AND PROTOCOL="..protocol end
   if(info ~= nil) then sql = sql .." AND (INFO='"..info.."')" end

   if((port ~= nil) and (port ~= "")) then sql = sql .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")" end

   if((host ~= nil) and (host ~= "")) then
   	if(version == 4) then
   		sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..host.."') OR IP_DST_ADDR=INET_ATON('"..host.."'))"
	else
		sql = sql .." AND (IP_SRC_ADDR='"..host.."' OR IP_DST_ADDR='"..host.."')"
	end
   end

   sql = sql.." order by bytes desc limit 2001"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
   	if(db_debug == true) then io.write(res.."\n") end
   	return nil
   else
   	return(res)
   end
end

if action == "get_peers" then
	local res = top_peers_query(ifId, ip_version, host, l4proto, port, l7proto, info, epoch_begin, epoch_end)
	local ndpi_protocols = {}
	for proto_name, proto_id in pairs(interface.getnDPIProtocols()) do
		ndpi_protocols[proto_id] = proto_name
	end
	for _,flow in pairs(res) do
		local peer_info = interface.getHostInfo(flow["peer"])
		if peer_info ~= nil then
			flow["peer"] = ntop.getResolvedAddress(hostinfo2hostkey(peer_info))
		end
		if ndpi_protocols[flow["l7proto"]] ~= "" then
			flow["l7proto"] = ndpi_protocols[flow["l7proto"]]
		end
	end
	sendHTTPHeader('application/json')
	print(json.encode(res, nil))
end
