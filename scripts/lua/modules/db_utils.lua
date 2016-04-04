--
-- (C) 2014-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"
require "lua_utils"

local db_debug = false

--- ====================================================================

function iptonumber(str)
   local num = 0
   for elem in str:gmatch("%d+") do
      num = num * 256 + assert(tonumber(elem))
   end
   return num
end


function expandIpV4Network(net)
   local prefix = net:match("/(.+)")
   address = net:gsub("/.+","")

   if(prefix == nil) then prefix = 32 end

   local num_hosts = 2^(32-prefix)
   local addr = iptonumber(address)

   return({ addr, addr+num_hosts-1 })
end


--- ====================================================================

function getInterfaceTopFlows(interface_id, version, host_or_profile, l7proto, l4proto, port, info, begin_epoch, end_epoch, offset, max_num_flows, sort_column, sort_order)
   -- CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON

   if(version == 4) then
      sql = "select INET_NTOA(IP_SRC_ADDR) AS IP_SRC_ADDR,INET_NTOA(IP_DST_ADDR) AS IP_DST_ADDR"
   else
      sql = "select IP_SRC_ADDR, IP_DST_ADDR"
   end

   follow = " ,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,BYTES,idx,L7_PROTO,INFO"
   if ntop.isPro() then follow = follow..",PROFILE" end
   follow = follow.." from flowsv"..version.." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch

   if((l7proto ~= "") and (l7proto ~= "-1")) then follow = follow .." AND L7_PROTO="..l7proto end
   if((l4proto ~= "") and (l4proto ~= "-1")) then follow = follow .." AND PROTOCOL="..l4proto end
   if(port ~= "") then follow = follow .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")" end
   if(info ~= "") then follow = follow .." AND (INFO='"..info.."')" end
   follow = follow.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   follow = follow.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if host_or_profile ~= nil and host_or_profile ~= "" and string.starts(host_or_profile, 'profile:') then
      host_or_profile = string.gsub(host_or_profile, 'profile:', '')
      follow = follow .. " AND (PROFILE='"..host_or_profile.."') "
   elseif host_or_profile ~= nil and host_or_profile ~= "" then
      if(version == 4) then
	 rsp = expandIpV4Network(host_or_profile)
	 follow = follow .." AND (((IP_SRC_ADDR>="..rsp[1]..") AND (IP_SRC_ADDR <= "..rsp[2].."))"
	 follow = follow .." OR ((IP_DST_ADDR>="..rsp[1]..") AND (IP_DST_ADDR <= "..rsp[2]..")))"
      else
	 follow = follow .." AND (IP_SRC_ADDR='"..host_or_profile.."' OR IP_DST_ADDR='"..host_or_profile.."')"
      end
   end

   follow = follow .." order by "..sort_column.." "..sort_order.." limit "..max_num_flows.." OFFSET "..offset

   sql = sql .. follow

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql, false) -- do not limit the maximum number of flows
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end

--- ====================================================================

function getFlowInfo(interface_id, version, flow_idx)
   version = tonumber(version)

   if(version == 4) then
      sql = "select INET_NTOA(IP_SRC_ADDR) AS IP_SRC_ADDR,INET_NTOA(IP_DST_ADDR) AS IP_DST_ADDR"
   else
      sql = "select IP_SRC_ADDR, IP_DST_ADDR"
   end

   follow = " ,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,BYTES,idx,L7_PROTO,INFO,CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON from flowsv"..version
   follow = follow.." where idx="..flow_idx
   sql = sql .. follow

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end

--- ====================================================================

function getNumFlows(interface_id, version, host, protocol, port, l7proto, info, begin_epoch, end_epoch)
   if(version == nil) then version = 4 end

   if(info == "") then info = nil end
   if(l7proto == "") then l7proto = nil end
   if(protocol == "") then protocol = nil end

   if l7proto ~= "" and l7proto ~= nil then
      if(not(isnumber(l7proto))) then
	 local id

	 l7proto = string.gsub(l7proto, "%.rrd", "")

	 if(string.ends(l7proto, ".rrd")) then l7proto = string.sub(l7proto, 1, -5) end

	 id = interface.getnDPIProtoId(l7proto)

	 if(id ~= -1) then
	    l7proto = id
	    title = "Top "..l7proto.." Flows"
	 else
	    l7proto = ""
	 end
      end
   end

   sql = "select COUNT(*) AS TOT_FLOWS, SUM(BYTES) AS TOT_BYTES, SUM(PACKETS) AS TOT_PACKETS FROM flowsv"..version.." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
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

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)

   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end


function getTopPeers(interface_id, version, host, protocol, port, l7proto, info, begin_epoch, end_epoch)
   if(host == nil or host == "") then return {} end
   if(version == nil) then version = 4 end

   if(info == "") then info = nil end
   if(l7proto == "") then l7proto = nil end
   if(protocol == "") then protocol = nil end

   sql = " SELECT "
   if(version == 4) then
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN INET_NTOA(IP_DST_ADDR) ELSE INET_NTOA(IP_SRC_ADDR) END PEER_ADDR, "
      -- when the selected host is the source, we consider its peer that is a destination an thus RECEIVES bytes and packets
      -- similarly, when the selected host is the destination, we consider its peer as a source that SENDS bytes and packets
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN BYTES ELSE 0 END peer_in_bytes, "
      sql = sql.." CASE WHEN IP_DST_ADDR = INET_ATON('"..host.."') THEN BYTES ELSE 0 END peer_out_bytes, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN PACKETS ELSE 0 END peer_in_packets, "
      sql = sql.." CASE WHEN IP_DST_ADDR = INET_ATON('"..host.."') THEN PACKETS ELSE 0 END peer_out_packets, "
   else
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IP_DST_ADDR ELSE IP_SRC_ADDR END PEER_ADDR, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN BYTES ELSE 0 END peer_in_bytes, "
      sql = sql.." CASE WHEN IP_DST_ADDR = '"..host.."' THEN BYTES ELSE 0 END peer_out_bytes, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN PACKETS ELSE 0 END peer_in_packets, "
      sql = sql.." CASE WHEN IP_DST_ADDR = '"..host.."' THEN PACKETS ELSE 0 END peer_out_packets, "
   end

   sql = sql.."sum(peer_in_bytes + peer_out_bytes) as TOT_BYTES, sum(peer_in_packets + peer_out_packets) as TOT_PACKETS, "
   sql = sql.."sum(peer_in_bytes) as IN_BYTES, sum(peer_in_packets) as IN_PACKETS, "
   sql = sql.."sum(peer_out_bytes) as OUT_BYTES, sum(peer_out_packets) as OUT_PACKETS, "
   sql = sql.."count(*) as TOT_FLOWS "
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

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by PEER_ADDR "

   sql = sql.." order by TOT_BYTES desc limit 10"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end

function getTopL7Protocols(interface_id, version, host, protocol, port, info, begin_epoch, end_epoch)
   if(host == nil or host == "") then return {} end
   if(version == nil) then version = 4 end

   if(info == "") then info = nil end
   if(protocol == "") then protocol = nil end

   sql = " SELECT L7_PROTO, "
   sql = sql.."sum(BYTES) as TOT_BYTES, sum(PACKETS) as TOT_PACKETS, count(*) as TOT_FLOWS "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

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

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by L7_PROTO "

   sql = sql.." order by TOT_BYTES desc limit 10"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end

function getOverallTopTalkersSELECT_FROM_WHERE_clause(src_or_dst, v4_or_v6, begin_epoch, end_epoch, ifid)
   local sql = ""
   local sql_bytes_packets = ""
   if src_or_dst     == "IP_DST_ADDR" then
      -- if this is a destination address, we account it INGRESS traffic
      sql_bytes_packets = "BYTES as in_bytes, PACKETS as in_packets,     0 as out_bytes,       0 as out_packets, "
   elseif src_or_dst == "IP_SRC_ADDR" then
      -- if this is a source address, we account the traffic as EGRESS
      sql_bytes_packets = "    0 as in_bytes,       0 as in_packets, BYTES as out_bytes, PACKETS as out_packets, "
   else
      return nil -- make sure to exit early if no valid data has been passed
   end
   if v4_or_v6 == 6 then
      sql = " SELECT NULL addrv4, "..src_or_dst.." addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM flowsv6 "
   elseif v4_or_v6 == 4 then -- ipv4
      sql = " SELECT "..src_or_dst.." addrv4, NULL addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM flowsv4 "
   else
      sql = ""
   end
   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL) "
   sql = sql.." AND (INTERFACE_ID='"..tonumber(ifid).."') "
   return sql..'\n'
end

function getOverallTopTalkers(interface_id, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- retrieves top talkers in the given time range
   if(info == "") then info = nil end

   -- AGGREGATE AND CRUNCH DATA
   sql = "select CASE WHEN addrv4 IS NOT NULL THEN INET_NTOA(addrv4) ELSE addrv6 END addr, "
   sql = sql.."SUM(in_bytes + out_bytes) tot_bytes, SUM(in_packets + out_packets) tot_packets, "
   sql = sql.."SUM(in_bytes)             in_bytes,               SUM(in_packets)  in_packets , "
   sql = sql.."SUM(out_bytes)            out_bytes,              SUM(out_packets) out_packets, "
   sql = sql.."count(*) tot_flows, "
   sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration from "

   sql = sql.."("
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 4, begin_epoch, end_epoch, interface_id)
   sql = sql.." UNION ALL "
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 4, begin_epoch, end_epoch, interface_id)
   sql = sql.." UNION ALL "
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 6, begin_epoch, end_epoch, interface_id)
   sql = sql.." UNION ALL "
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 6, begin_epoch, end_epoch, interface_id)
   sql = sql..") talkers"
   sql = sql.." group by addr "

   -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if     sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   elseif sort_column == "column_in_packets" or sort_column == "in_packets" then
      order_by_column = "in_packets"
   elseif sort_column == "column_out_packets" or sort_column == "out_packets" then
      order_by_column = "out_packets"
   elseif sort_column == "column_in_bytes" or sort_column == "in_bytes" then
      order_by_column = "in_bytes"
   elseif sort_column == "column_out_bytes" or sort_column == "out_bytes" then
      order_by_column = "out_bytes"
   elseif sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "tot_flows"
   elseif sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
      order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local sclice_limit = 100
   if tonumber(offset) >= 0 then slice_offset = offset end
   if tonumber(limit) > 0 then slice_limit = limit end
   sql = sql.."limit "..slice_offset..","..slice_limit.." "

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end


function getHostTopTalkers(interface_id, host, l7_proto_id, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- obtains host top talkers, possibly restricting the range only to l7_proto_id
   if host == nil or host == "" then return {} end

   local version = 4
   if isIPv6(host) then version = 6 end
   if(info == "") then info = nil end

   sql = " SELECT addr, "
   sql = sql.."sum(peer_in_bytes + peer_out_bytes) as tot_bytes, sum(peer_in_packets + peer_out_packets) as tot_packets, "
   sql = sql.."sum(peer_in_bytes) as in_bytes, sum(peer_in_packets) as in_packets, "
   sql = sql.."sum(peer_out_bytes) as out_bytes, sum(peer_out_packets) as out_packets, "
   sql = sql.."count(*) as flows, "
   sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration "

   sql = sql .. "FROM ( SELECT "
   if(version == 4) then
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN INET_NTOA(IP_DST_ADDR) ELSE INET_NTOA(IP_SRC_ADDR) END addr, "
      -- when the selected host is the source, we consider its peer that is a destination an thus RECEIVES bytes and packets
      -- similarly, when the selected host is the destination, we consider its peer as a source that SENDS bytes and packets
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN BYTES ELSE 0 END peer_in_bytes, "
      sql = sql.." CASE WHEN IP_DST_ADDR = INET_ATON('"..host.."') THEN BYTES ELSE 0 END peer_out_bytes, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN PACKETS ELSE 0 END peer_in_packets, "
      sql = sql.." CASE WHEN IP_DST_ADDR = INET_ATON('"..host.."') THEN PACKETS ELSE 0 END peer_out_packets, "
   else
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IP_DST_ADDR ELSE IP_SRC_ADDR END peer_addr, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN BYTES ELSE 0 END peer_in_bytes, "
      sql = sql.." CASE WHEN IP_DST_ADDR = '"..host.."' THEN BYTES ELSE 0 END peer_out_bytes, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN PACKETS ELSE 0 END peer_in_packets, "
      sql = sql.." CASE WHEN IP_DST_ADDR = '"..host.."' THEN PACKETS ELSE 0 END peer_out_packets, "
   end
   sql = sql.." FIRST_SWITCHED, LAST_SWITCHED "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if(info ~= nil) then sql = sql .." AND (INFO='"..info.."')" end

   if l7_proto_id and L7_proto_id ~="" then sql = sql.." AND L7_PROTO = "..tonumber(l7_proto_id) end

   if(version == 4) then
      sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..host.."') OR IP_DST_ADDR=INET_ATON('"..host.."'))"
   else
      sql = sql .." AND (IP_SRC_ADDR='"..host.."' OR IP_DST_ADDR='"..host.."')"
   end

   sql = sql..") peers"

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by addr "

      -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   elseif sort_column == "column_bytes" or sort_column == "bytes" or sort_column == "tot_bytes" then
      order_by_column = "tot_bytes"
   elseif sort_column == "column_peer_in_packets" or sort_column == "in_packets" then
      order_by_column = "in_packets"
   elseif sort_column == "column_peer_out_packets" or sort_column == "out_packets" then
      order_by_column = "out_packets"
   elseif sort_column == "column_peer_in_bytes" or sort_column == "in_bytes" then
      order_by_column = "in_bytes"
   elseif sort_column == "column_peer_out_bytes" or sort_column == "out_bytes" then
      order_by_column = "out_bytes"
   elseif sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "flows"
   elseif sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
      order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local sclice_limit = 100
   if tonumber(offset) >= 0 then slice_offset = offset end
   if tonumber(limit) > 0 then slice_limit = limit end
   sql = sql.."limit "..slice_offset..","..slice_limit.." "

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)

   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end

function getAppTopTalkersSELECT_FROM_WHERE_clause(src_or_dst, v4_or_v6, begin_epoch, end_epoch, ifid, l7_proto_id)
   local sql = ""
   local sql_bytes_packets = ""
   if src_or_dst     == "IP_DST_ADDR" then
      -- if this is a destination address, we account it INGRESS traffic
      sql_bytes_packets = "BYTES as in_bytes, PACKETS as in_packets,     0 as out_bytes,       0 as out_packets, "
   elseif src_or_dst == "IP_SRC_ADDR" then
      -- if this is a source address, we account the traffic as EGRESS
      sql_bytes_packets = "    0 as in_bytes,       0 as in_packets, BYTES as out_bytes, PACKETS as out_packets, "
   else
      return nil -- make sure to exit early if no valid data has been passed
   end
   if v4_or_v6 == 6 then
      sql = " SELECT NULL addrv4, "..src_or_dst.." addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM flowsv6 "
   elseif v4_or_v6 == 4 then -- ipv4
      sql = " SELECT "..src_or_dst.." addrv4, NULL addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM flowsv4 "
   else
      sql = ""
   end
   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL) "
   sql = sql.." AND (INTERFACE_ID='"..tonumber(ifid).."') "
   sql = sql.." AND L7_PROTO = "..tonumber(l7_proto_id)
   return sql..'\n'
end

function getAppTopTalkers(interface_id, l7_proto_id, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- retrieves top talkers in the given time range
   if(info == "") then info = nil end

   -- AGGREGATE AND CRUNCH DATA
   sql = "select CASE WHEN addrv4 IS NOT NULL THEN INET_NTOA(addrv4) ELSE addrv6 END addr, "
   sql = sql.."SUM(in_bytes + out_bytes) tot_bytes, SUM(in_packets + out_packets) tot_packets, "
   sql = sql.."SUM(in_bytes)             in_bytes,               SUM(in_packets)  in_packets , "
   sql = sql.."SUM(out_bytes)            out_bytes,              SUM(out_packets) out_packets, "
   sql = sql.."count(*) tot_flows, "
   sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration from "

   sql = sql.."("
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 4, begin_epoch, end_epoch, interface_id, l7_proto_id)
   sql = sql.." UNION ALL "
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 4, begin_epoch, end_epoch, interface_id, l7_proto_id)
   sql = sql.." UNION ALL "
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 6, begin_epoch, end_epoch, interface_id, l7_proto_id)
   sql = sql.." UNION ALL "
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 6, begin_epoch, end_epoch, interface_id, l7_proto_id)
   sql = sql..") talkers"
   sql = sql.." group by addr "

   -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   elseif sort_column == "column_in_packets" or sort_column == "in_packets" then
      order_by_column = "in_packets"
   elseif sort_column == "column_out_packets" or sort_column == "out_packets" then
      order_by_column = "out_packets"
   elseif sort_column == "column_in_bytes" or sort_column == "in_bytes" then
      order_by_column = "in_bytes"
   elseif sort_column == "column_out_bytes" or sort_column == "out_bytes" then
      order_by_column = "out_bytes"
   elseif sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "tot_flows"
   elseif sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
      order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local sclice_limit = 100
   if tonumber(offset) >= 0 then slice_offset = offset end
   if tonumber(limit) > 0 then slice_limit = limit end
   sql = sql.."limit "..slice_offset..","..slice_limit.." "

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end

function getTopApplications(interface_id, peer1, peer2, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- if both peers are nil, top applications are overall in the time range
   -- if peer1 is nil nad peer2 is not nil, then top apps are for peer1
   -- if peer2 is nil nad peer1 is not nil, then top apps are for peer2
   -- if both peer2 and peer2 are not nil, then top apps are computed between peer1 and peer2
   -- sort_column and sort_order are used to sort the results
   -- offset and limit are used to paginate the results
   local version = 4
   if peer1 and peer1 ~= "" and isIPv6(peer1) then version = 6
   elseif peer2 and peer2 ~= "" and isIPv6(peer2) then version = 6 end
   if(info == "") then info = nil end

   sql = " SELECT L7_PROTO application, "
   sql = sql.."sum(BYTES) as tot_bytes, sum(PACKETS) as tot_packets, count(*) as tot_flows, "
   sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if(info ~= nil) then sql = sql .." AND (INFO='"..info.."')" end

   if peer1 and peer1 ~= "" then
      if(version == 4) then
	 sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..peer1.."') OR IP_DST_ADDR=INET_ATON('"..peer1.."')) "
      else
	 sql = sql .." AND (IP_SRC_ADDR='"..peer1.."' OR IP_DST_ADDR='"..peer1.."') "
      end
   end
   if peer2 and peer2 ~= "" then
      if(version == 4) then
	 sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..peer2.."') OR IP_DST_ADDR=INET_ATON('"..peer2.."'))"
      else
	 sql = sql .." AND (IP_SRC_ADDR='"..peer2.."' OR IP_DST_ADDR='"..peer2.."')"
      end
   end


   sql = sql.." group by L7_PROTO "

   -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   end
   if sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "tot_flows"
   end
   if sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
      order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local sclice_limit = 100
   if tonumber(offset) >= 0 then slice_offset = offset end
   if tonumber(limit) > 0 then slice_limit = limit end
   sql = sql.."limit "..slice_offset..","..slice_limit.." "

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end


function getPeersTrafficHistogram(interface_id, peer1, peer2, info, begin_epoch, end_epoch)
   if peer1 == nil or peer1 == "" or peer2 == nil or peer2 == "" then return {} end

   local max_bins = 2000  -- do not return more than 2k datapoints
   local interval = end_epoch - begin_epoch  -- the larger the interval the coarser the aggregation
   local bin_width = math.floor(interval / max_bins)

   local version = 4
   if isIPv6(peer1) then version = 6 end
   if(info == "") then info = nil end

   if(version == 4) then
      sql = " SELECT INET_NTOA(least(IP_SRC_ADDR, IP_DST_ADDR)) peer1_addr, INET_NTOA(greatest(IP_SRC_ADDR, IP_DST_ADDR)) peer2_addr, "
   else
      sql = " SELECT least(IP_SRC_ADDR, IP_DST_ADDR) peer1_addr, greatest(IP_SRC_ADDR, IP_DST_ADDR) peer2_addr, "
   end
   sql = sql.." MIN(FIRST_SWITCHED) first_switched_bin, " -- the oldest datapoint in each bin
   sql = sql.." sum(BYTES) as tot_bytes, sum(PACKETS) as tot_packets, count(*) as tot_flows, "
   sql = sql.." (sum(FIRST_SWITCHED) - sum(LAST_SWITCHED)) / count(*) as avg_flow_duration "

   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if(info ~= nil) then sql = sql .." AND (INFO='"..info.."')" end

   if(version == 4) then
      sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..peer1.."') OR IP_DST_ADDR=INET_ATON('"..peer2.."'))"
      sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..peer2.."') OR IP_DST_ADDR=INET_ATON('"..peer2.."'))"
   else
      sql = sql .." AND (IP_SRC_ADDR='"..peer1.."' OR IP_DST_ADDR='"..peer2.."')"
      sql = sql .." AND (IP_SRC_ADDR='"..peer2.."' OR IP_DST_ADDR='"..peer2.."')"
   end

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by least(IP_SRC_ADDR, IP_DST_ADDR), greatest(IP_SRC_ADDR, IP_DST_ADDR), FIRST_SWITCHED DIV ("..bin_width..")"

   sql = sql.." order by TOT_BYTES desc limit 100"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return {}
   elseif res == nil then
      return {}
   else
      return(res)
   end
end
