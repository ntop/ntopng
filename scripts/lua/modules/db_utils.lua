--
-- (C) 2014-15 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"
require "lua_utils"
require "flow_aggregation_utils"

local db_debug = false

local db_utils = {}

-- ########################################################

local function iptonumber(str)
   local num = 0
   for elem in str:gmatch("%d+") do
      num = num * 256 + assert(tonumber(elem))
   end
   return num
end

-- ########################################################

function expandIpV4Network(net)
   local address, prefix = splitNetworkPrefix(net)

   if(prefix == nil or prefix > 32 or prefix < 0) then prefix = 32 end

   local num_hosts = 2^(32-prefix)
   local addr = iptonumber(address)

   for i=1,32-prefix do
      addr = clearbit(addr, bit(i))
   end

   return({ addr, addr+num_hosts-1 })
end

-- ########################################################

local function flowsTableName(version, force_raw)
   if tblname_prefs == nil then
      tblname_prefs = ntop.getPrefs()
   end

   local tblname = "flowsv"..version

   if force_raw ~= true and ntop.isEnterprise() == true then
      if useAggregatedFlows() == true then
	 tblname = "aggr"..tblname
      end
   end

   -- return "flowsv"..version -- FIXX: remove this line when ready
   return tblname
end

-- ########################################################

local function allowedNetworksIter(version)
   if version ~= 4 and version ~= 6 then
      return function() return nil end
   end

   local an = ntop.getAllowedNetworks()..","
   local spl = an:split(",")
   local pos = 0

   return function()
      while pos < #spl do
	 pos = pos + 1
	 local net = spl[pos]
	 local v6_net = not isIPv4Network(net)

	 if (v6_net and version == 6) or (not v6_net and version == 4) then
	    return net
	 end
      end
   end
end

-- ########################################################

function allowedNetworksRestrictions()
   for net in allowedNetworksIter(6) do
      if net:match('[1-9a-fA-F]') then
	 return true
      end
   end

   for net in allowedNetworksIter(4) do
      local expanded = expandIpV4Network(net)
      if (expanded[1] > 0 or expanded[2] < 2^32 - 1) then
	 return true
      end
   end

   return false
end

-- ########################################################

local function allowedNetworksFilter(follow, version, filter_src, filter_dst)
   local an = ntop.getAllowedNetworks()..","
   local v4_expanded = {}
   local expanded_src = {}
   local expanded_dst = {}

   for net in allowedNetworksIter(version) do
      -- tprint({net=net, match=net:match('[1-9]'), version=version})

      if version == 6 and net:match('[1-9a-fA-F]') then
	 -- no results when we've a non-zero ipv6 allowed network
	 return follow.." AND 1 = 0 "
      end

      if version == 4 then
	 local expanded = expandIpV4Network(net)
	 local filter = {}

	 if filter_src and (expanded[1] > 0 or expanded[2] < 2^32 - 1) then
	    expanded_src[#expanded_src + 1] = string.format(" (IP_SRC_ADDR >= %d AND IP_SRC_ADDR <= %d) ", expanded[1], expanded[2])
	 end

	 if filter_dst and (expanded[1] > 0 or expanded[2] < 2^32 - 1) then
	    expanded_dst[#expanded_dst + 1] = string.format(" (IP_DST_ADDR >= %d AND IP_DST_ADDR <= %d) ", expanded[1], expanded[2])
	 end
      end
   end

   local res = "1 = 1"
   if version == 4 then
      -- multiple allowed networks must be evaluated in OR
      local r = {}

      if table.len(expanded_src) > 0 then
	 r[#r + 1] = string.format(" (%s) ", table.concat(expanded_src, " OR "))
      end

      if table.len(expanded_dst) > 0 then
	 r[#r + 1] = string.format(" (%s) ", table.concat(expanded_dst, " OR "))
      end

      if table.len(r) > 0 then
	 res = table.concat(r, " AND ")
      end

   elseif version == 6 then
      -- TODO: implement filtering for ipv6 networks
   end

   return string.format("%s AND (%s)", follow, res)
end

-- ########################################################

function getInterfaceTopFlows(interface_id, version, host_or_profile, peer, l7proto, l4proto, port, vlan, profile, info, begin_epoch, end_epoch, offset, max_num_flows, sort_column, sort_order, aggregated_flows)
   -- CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON

   if(version == 4) then
      sql = "select INET_NTOA(IP_SRC_ADDR) AS IP_SRC_ADDR,INET_NTOA(IP_DST_ADDR) AS IP_DST_ADDR"
   else
      sql = "select IP_SRC_ADDR, IP_DST_ADDR"
   end

   follow = " ,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,IN_BYTES + OUT_BYTES as BYTES,IN_BYTES,OUT_BYTES,idx,L7_PROTO,INFO"
   if ntop.isPro() then follow = follow..",PROFILE" end

   follow = follow.." from "..flowsTableName(version, true --[[ force raw flows --]]).." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch

   if((l7proto ~= "") and (l7proto ~= "-1")) then follow = follow .." AND L7_PROTO="..l7proto end
   if((l4proto ~= "") and (l4proto ~= "-1")) then follow = follow .." AND PROTOCOL="..l4proto end
   if(port ~= "") then follow = follow .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")" end
   if((vlan ~= nil) and (vlan ~= "")) then follow = follow .." AND VLAN_ID="..vlan end
   if((profile ~= nil) and (profile ~= "")) then follow = follow .." AND PROFILE='"..profile.."'" end
   if(info ~= "") then follow = follow .." AND (INFO LIKE '%"..info.."%')" end
   follow = follow.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='')"
   follow = follow.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if host_or_profile ~= nil and host_or_profile ~= "" and string.starts(host_or_profile, 'profile:') then
      host_or_profile = string.gsub(host_or_profile, 'profile:', '')
      follow = follow .. " AND (PROFILE='"..host_or_profile.."') "
   elseif host_or_profile ~= nil and host_or_profile ~= "" then
      if(version == 4) then
	 rsp = expandIpV4Network(host_or_profile)
	 follow = follow .." AND ((IP_SRC_ADDR>="..rsp[1].." AND IP_SRC_ADDR <= "..rsp[2]..")"
	 follow = follow .." OR   (IP_DST_ADDR>="..rsp[1].." AND IP_DST_ADDR <= "..rsp[2].."))"
	 if peer ~= nil and peer ~= "" then
	    rsp = expandIpV4Network(peer)
	    follow = follow .." AND ((IP_SRC_ADDR>="..rsp[1].." AND IP_SRC_ADDR <= "..rsp[2]..")"
	    follow = follow .." OR   (IP_DST_ADDR>="..rsp[1].." AND IP_DST_ADDR <= "..rsp[2].."))"
	 end
      else
	 follow = follow .." AND (IP_SRC_ADDR='"..host_or_profile.."' OR IP_DST_ADDR='"..host_or_profile.."')"
	 if peer ~= nil and peer ~= "" then
	    follow = follow .." AND (IP_SRC_ADDR='"..peer.."' OR IP_DST_ADDR='"..peer.."')"
	 end
      end
   end

   follow = allowedNetworksFilter(follow, version, true, true)

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

-- ########################################################

function getFlowInfo(interface_id, version, flow_idx)
   version = tonumber(version)

   if(version == 4) then
      sql = "select INET_NTOA(IP_SRC_ADDR) AS IP_SRC_ADDR,INET_NTOA(IP_DST_ADDR) AS IP_DST_ADDR"
   else
      sql = "select IP_SRC_ADDR, IP_DST_ADDR"
   end

   follow = " ,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,IN_BYTES, OUT_BYTES, IN_BYTES + OUT_BYTES as BYTES,idx,L7_PROTO,INFO,CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON from flowsv"..version
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

-- ########################################################

function getNumFlows(interface_id, version, host, protocol, port, l7proto, info, vlan, profile, begin_epoch, end_epoch, force_raw_flows, enforce_allowed_networks)
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

   sql = "select COUNT(*) AS TOT_FLOWS, SUM(IN_BYTES + OUT_BYTES) AS TOT_BYTES, SUM(PACKETS) AS TOT_PACKETS FROM "..flowsTableName(version, force_raw_flows --[[force count from raw flows --]]).." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='')"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if((l7proto ~= nil) and (l7proto ~= "")) then sql = sql .." AND L7_PROTO="..l7proto end
   if((protocol ~= nil) and (protocol ~= "")) then sql = sql .." AND PROTOCOL="..protocol end
   if((vlan ~= nil) and (vlan ~= "")) then sql = sql .." AND VLAN_ID="..vlan end
   if((profile ~= nil) and (profile ~= "")) then sql = sql .." AND PROFILE='"..profile.."'" end
   if(info ~= nil) then sql = sql .." AND (INFO LIKE '%"..info.."%')" end

   if((port ~= nil) and (port ~= "")) then sql = sql .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")" end

   if((host ~= nil) and (host ~= "")) then
      if(version == 4) then
	 local ip_range = expandIpV4Network(host)
	 local ip_lowest  = ip_range[1]
	 local ip_highest = ip_range[2]

	 if ip_lowest == ip_highest then
	    sql = sql .." AND (IP_SRC_ADDR='"..ip_highest.."' OR IP_DST_ADDR='"..ip_highest.."')"
	 else
	    sql = sql .." AND ((IP_SRC_ADDR>='"..ip_lowest.."' AND IP_SRC_ADDR<='"..ip_highest.."')"
	    sql = sql .." OR (IP_DST_ADDR>='"..ip_lowest.."' AND IP_DST_ADDR<='"..ip_highest.."'))"
	 end
      else
	 sql = sql .." AND (IP_SRC_ADDR='"..host.."' OR IP_DST_ADDR='"..host.."')"
      end
   end

   if enforce_allowed_networks then
      sql = allowedNetworksFilter(sql, version, true, true)
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

-- ########################################################

function getOverallTopTalkersSELECT_FROM_WHERE_clause(src_or_dst, v4_or_v6, begin_epoch, end_epoch, ifid, l4proto, port, vlan, profile)
   local sql = ""
   local sql_bytes_packets = "PACKETS as packets, "
   local exclude_same_src_dst = false
   if src_or_dst     == "IP_DST_ADDR" then
      exclude_same_src_dst = true
      -- if this is a destination address, we account it INGRESS traffic
      sql_bytes_packets = sql_bytes_packets .. "OUT_BYTES as bytes_sent, IN_BYTES  as bytes_rcvd, "
   elseif src_or_dst == "IP_SRC_ADDR" then
      -- if this is a source address, we account the traffic as EGRESS
      sql_bytes_packets = sql_bytes_packets .. " IN_BYTES as bytes_sent, OUT_BYTES as bytes_rcvd, "
   else
      return nil -- make sure to exit early if no valid data has been passed
   end

   if v4_or_v6 == 6 then
      sql = " SELECT NULL addrv4, "..src_or_dst.." addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM "..flowsTableName(6).." "
   elseif v4_or_v6 == 4 then -- ipv4
      sql = " SELECT "..src_or_dst.." addrv4, NULL addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM "..flowsTableName(4).." "
   else
      sql = ""
   end
   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='') "
   sql = sql.." AND (INTERFACE_ID='"..tonumber(ifid).."') "
   if(exclude_same_src_dst == true) then
      -- avoid double counting flows that have source == destination
      sql = sql.." AND IP_SRC_ADDR <> IP_DST_ADDR"
   end
   if((l4proto ~= nil) and (l4proto ~= "") and (l4proto ~= "-1")) then
      sql = sql .." AND PROTOCOL="..l4proto
   end
   if((port ~= nil) and (port ~= "")) then
      sql = sql .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")"
   end

   if((vlan ~= nil) and (vlan ~= "")) then
      sql = sql .." AND VLAN_ID="..vlan
   end

   if((profile ~= nil) and (profile ~= "")) then
      sql = sql .." AND PROFILE='"..profile.."'"
   end

   if src_or_dst     == "IP_DST_ADDR" then
      sql = allowedNetworksFilter(sql, v4_or_v6, false, true)
   elseif src_or_dst == "IP_SRC_ADDR" then
      sql = allowedNetworksFilter(sql, v4_or_v6, true, false)
   end

   return sql..'\n'
end

-- ########################################################

function getOverallTopTalkers(interface_id, l4proto, port, vlan, profile, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- retrieves top talkers in the given time range

   if(info == "") then info = nil end

   -- AGGREGATE AND CRUNCH DATA
   sql = "select CASE WHEN addrv4 IS NOT NULL THEN INET_NTOA(addrv4) ELSE addrv6 END addr, "
   sql = sql.."SUM(bytes_sent + bytes_rcvd) tot_bytes, SUM(packets) tot_packets, "
   sql = sql.."SUM(bytes_sent)             bytes_sent, "
   sql = sql.."SUM(bytes_rcvd)             bytes_rcvd, "
   sql = sql.."count(*) tot_flows "
   -- sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration "
   sql = sql.." FROM "

   sql = sql.."("
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 4, begin_epoch, end_epoch, interface_id, l4proto, port, vlan, profile)
   sql = sql.." UNION ALL "
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 4, begin_epoch, end_epoch, interface_id, l4proto, port, vlan, profile)
   sql = sql.." UNION ALL "
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 6, begin_epoch, end_epoch, interface_id, l4proto, port, vlan, profile)
   sql = sql.." UNION ALL "
   sql = sql..getOverallTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 6, begin_epoch, end_epoch, interface_id, l4proto, port, vlan, profile)
   sql = sql..") talkers"
   sql = sql.." group by addr "

   -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if     sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   elseif sort_column == "column_bytes_sent" or sort_column == "bytes_sent" then
      order_by_column = "bytes_sent"
   elseif sort_column == "column_bytes_rcvd" or sort_column == "bytes_rcvd" then
      order_by_column = "bytes_rcvd"
   elseif sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "tot_flows"
   -- elseif sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
   --   order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local slice_limit = 100
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

-- ########################################################

function getHostTopTalkers(interface_id, host, l7_proto_id, l4_proto_id, port, vlan, profile, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- obtains host top talkers, possibly restricting the range only to l7_proto_id
   if host == nil or host == "" then return {} end

   local version = 4
   if isIPv6(host) then version = 6 end
   if(info == "") then info = nil end

   sql = " SELECT addr, "
   sql = sql.."sum(peer_bytes_sent + peer_bytes_rcvd) as tot_bytes, sum(peer_packets) as tot_packets, "
   sql = sql.."sum(peer_bytes_sent) as bytes_sent, "
   sql = sql.."sum(peer_bytes_rcvd) as bytes_rcvd, "
   sql = sql.."count(*) as flows "
   -- sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration "

   sql = sql .. "FROM ( SELECT PACKETS as peer_packets, "
   if(version == 4) then
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN INET_NTOA(IP_DST_ADDR) ELSE INET_NTOA(IP_SRC_ADDR) END addr, "
      -- when the selected host is the source, we consider its peer that is a destination an thus RECEIVES bytes and packets
      -- similarly, when the selected host is the destination, we consider its peer as a source that SENDS bytes and packets
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN OUT_BYTES ELSE IN_BYTES  END peer_bytes_sent, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN IN_BYTES  ELSE OUT_BYTES END peer_bytes_rcvd, "
   else
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IP_DST_ADDR ELSE IP_SRC_ADDR END addr, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN OUT_BYTES ELSE IN_BYTES  END peer_bytes_sent, "
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IN_BYTES  ELSE OUT_BYTES END peer_bytes_rcvd, "
   end
   sql = sql.." FIRST_SWITCHED, LAST_SWITCHED "
   sql = sql.." FROM "..flowsTableName(version)

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='')"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if((port ~= nil) and (port ~= "")) then
      sql = sql .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")"
   end

   if((vlan ~= nil) and (vlan ~= "")) then
      sql = sql .." AND VLAN_ID="..vlan
   end

   if((profile ~= nil) and (profile ~= "")) then
      sql = sql .." AND PROFILE='"..profile.."'"
   end
   if(info ~= nil) then
      sql = sql .." AND (INFO LIKE '%"..info.."%')"
   end

   if l7_proto_id and l7_proto_id ~="" then sql = sql.." AND L7_PROTO = "..tonumber(l7_proto_id) end
   if l4_proto_id and l4_proto_id ~="" then sql = sql.." AND PROTOCOL = "..tonumber(l4_proto_id) end

   if(version == 4) then
      sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..host.."') OR IP_DST_ADDR=INET_ATON('"..host.."'))"
   else
      sql = sql .." AND (IP_SRC_ADDR='"..host.."' OR IP_DST_ADDR='"..host.."')"
   end

   sql = allowedNetworksFilter(sql, version, true, true)

   sql = sql..") peers"

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by addr "

      -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   elseif sort_column == "column_bytes" or sort_column == "bytes" or sort_column == "tot_bytes" then
      order_by_column = "tot_bytes"
   elseif sort_column == "column_bytes_sent" or sort_column == "bytes_sent" then
      order_by_column = "bytes_sent"
   elseif sort_column == "column_bytes_rcvd" or sort_column == "bytes_rcvd" then
      order_by_column = "bytes_rcvd"
   elseif sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "flows"
  --  elseif sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
  --     order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local slice_limit = 100
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

-- ########################################################

function getAppTopTalkersSELECT_FROM_WHERE_clause(src_or_dst, v4_or_v6, begin_epoch, end_epoch, ifid, l7_proto_id, l4_proto_id, port, vlan, profile)
   local sql = ""
   local sql_bytes_packets = "PACKETS as packets, "
   local exclude_same_src_dst = false
   if src_or_dst     == "IP_DST_ADDR" then
      exclude_same_src_dst = true
      -- if this is a destination address, we account it INGRESS traffic
      sql_bytes_packets = sql_bytes_packets .. "OUT_BYTES as bytes_sent, IN_BYTES  as bytes_rcvd, "
   elseif src_or_dst == "IP_SRC_ADDR" then
      -- if this is a source address, we account the traffic as EGRESS
      sql_bytes_packets = sql_bytes_packets .. " IN_BYTES as bytes_sent, OUT_BYTES as bytes_rcvd, "
   else
      return nil -- make sure to exit early if no valid data has been passed
   end

   if v4_or_v6 == 6 then
      sql = " SELECT NULL addrv4, "..src_or_dst.." addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM "..flowsTableName(6).." "
   elseif v4_or_v6 == 4 then -- ipv4
      sql = " SELECT "..src_or_dst.." addrv4, NULL addrv6, "
      sql = sql..sql_bytes_packets
      sql = sql.."FIRST_SWITCHED, LAST_SWITCHED FROM "..flowsTableName(4).." "
   else
      sql = ""
   end

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='') "
   sql = sql.." AND (INTERFACE_ID='"..tonumber(ifid).."') "
   sql = sql.." AND L7_PROTO = "..tonumber(l7_proto_id)
   if(exclude_same_src_dst == true) then
      -- avoid double counting flows that have source == destination
      sql = sql.." AND IP_SRC_ADDR <> IP_DST_ADDR"
   end
   if((l4_proto_id ~= nil) and (l4_proto_id ~= "") and (l4_proto_id ~= "-1")) then
      sql = sql .." AND PROTOCOL="..l4_proto_id
   end
   if((port ~= nil) and (port ~= "")) then
      sql = sql .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")"
   end

   if((vlan ~= nil) and (vlan ~= "")) then
      sql = sql .." AND VLAN_ID="..vlan
   end

   if((profile ~= nil) and (profile ~= "")) then
      sql = sql .." AND PROFILE='"..profile.."'"
   end

   if src_or_dst     == "IP_DST_ADDR" then
      sql = allowedNetworksFilter(sql, v4_or_v6, false, true)
   elseif src_or_dst == "IP_SRC_ADDR" then
      sql = allowedNetworksFilter(sql, v4_or_v6, true, false)
   end

   return sql..'\n'
end

-- ########################################################

function getAppTopTalkers(interface_id, l7_proto_id, l4_proto_id, port, vlan, profile, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- retrieves top talkers in the given time range
   if(info == "") then info = nil end

   -- AGGREGATE AND CRUNCH DATA
   sql = "select CASE WHEN addrv4 IS NOT NULL THEN INET_NTOA(addrv4) ELSE addrv6 END addr, "
   sql = sql.."SUM(bytes_sent + bytes_rcvd) tot_bytes, SUM(packets) tot_packets, "
   sql = sql.."SUM(bytes_sent)             bytes_sent, "
   sql = sql.."SUM(bytes_rcvd)             bytes_rcvd, "
   sql = sql.."count(*) tot_flows "
   -- sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration "
   sql = sql.." FROM "

   sql = sql.."("
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 4, begin_epoch, end_epoch, interface_id, l7_proto_id, l4_proto_id, port, vlan, profile)
   sql = sql.." UNION ALL "
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 4, begin_epoch, end_epoch, interface_id, l7_proto_id, l4_proto_id, port, vlan, profile)
   sql = sql.." UNION ALL "
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_SRC_ADDR', 6, begin_epoch, end_epoch, interface_id, l7_proto_id, l4_proto_id, port, vlan, profile)
   sql = sql.." UNION ALL "
   sql = sql..getAppTopTalkersSELECT_FROM_WHERE_clause('IP_DST_ADDR', 6, begin_epoch, end_epoch, interface_id, l7_proto_id, l4_proto_id, port, vlan, profile)
   sql = sql..") talkers"
   sql = sql.." group by addr "

   -- ORDER
   local order_by_column = "tot_bytes" -- defaults to tot_bytes
   if sort_column == "column_packets" or sort_column == "packets" or sort_column == "tot_packets" then
      order_by_column = "tot_packets"
   elseif sort_column == "column_bytes_sent" or sort_column == "bytes_sent" then
      order_by_column = "bytes_sent"
   elseif sort_column == "column_bytes_rcvd" or sort_column == "bytes_rcvd" then
      order_by_column = "bytes_rcvd"
   elseif sort_column == "column_flows" or sort_column == "flows" or sort_column == "tot_flows" then
      order_by_column = "tot_flows"
   -- elseif sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
   --    order_by_column = "avg_flow_duration"
   end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local slice_limit = 100
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

-- ########################################################

function getTopApplications(interface_id, peer1, peer2, l7_proto_id, l4_proto_id, port, vlan, profile, info, begin_epoch, end_epoch, sort_column, sort_order, offset, limit)
   -- tprint({n="getTopApplications", peer1=peer1, peer2=peer2})
   -- if both peers are nil, top applications are overall in the time range
   -- if peer1 is nil and peer2 is not nil, then top apps are for peer1
   -- if peer2 is nil and peer1 is not nil, then top apps are for peer2
   -- if both peer2 and peer2 are not nil, then top apps are computed between peer1 and peer2
   -- sort_column and sort_order are used to sort the results
   -- offset and limit are used to paginate the results
   local version = 4
   if peer1 and peer1 ~= "" and isIPv6(peer1) then version = 6
   elseif peer2 and peer2 ~= "" and isIPv6(peer2) then version = 6 end
   if(info == "") then info = nil end

   sql = " SELECT L7_PROTO application, "
   sql = sql.."sum(IN_BYTES + OUT_BYTES) as tot_bytes, sum(PACKETS) as tot_packets, count(*) as tot_flows "
   -- sql = sql.." (sum(LAST_SWITCHED) - sum(FIRST_SWITCHED)) / count(*) as avg_flow_duration "
   sql = sql.." FROM "..flowsTableName(version)

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='')"
   sql = sql.." AND (INTERFACE_ID='"..tonumber(interface_id).."')"

   if((port ~= nil) and (port ~= "")) then
      sql = sql .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")"
   end

   if((vlan ~= nil) and (vlan ~= "")) then
      sql = sql .." AND VLAN_ID="..vlan
   end

   if((profile ~= nil) and (profile ~= "")) then
      sql = sql .." AND PROFILE='"..profile.."'"
   end

   if l7_proto_id and l7_proto_id ~="" then sql = sql.." AND L7_PROTO = "..tonumber(l7_proto_id) end
   if l4_proto_id and l4_proto_id ~="" then sql = sql.." AND PROTOCOL = "..tonumber(l4_proto_id) end
   if(info ~= nil) then sql = sql .." AND (INFO LIKE '%"..info.."%')" end

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
   -- if sort_column == "column_avg_flow_duration" or sort_column == "avg_flow_duration" then
   --   order_by_column = "avg_flow_duration"
   --end

   local order_by_order = "desc"
   if sort_order == "asc" then order_by_order = "asc" end
   sql = sql.." order by "..order_by_column.." "..order_by_order.." "

   -- SLICE
   local slice_offset = 0
   local slice_limit = 100
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

-- ########################################################

function db_utils.harverstExpiredMySQLFlows(ifname, mysql_retention, verbose)
   interface.select(ifname)

   local dbtables = {"flowsv4", "flowsv6"}
   if useAggregatedFlows() then
      dbtables[#dbtables+1] = "aggrflowsv4"
      dbtables[#dbtables+1] = "aggrflowsv6"
   end

   for _, tb in pairs(dbtables) do
      local sql = "DELETE FROM "..tb.." where FIRST_SWITCHED < "..mysql_retention
      sql = sql.." AND (INTERFACE_ID = "..getInterfaceId(ifname)..")"
      sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."' OR NTOPNG_INSTANCE_NAME IS NULL OR NTOPNG_INSTANCE_NAME='')"
      interface.execSQLQuery(sql)
      if(verbose) then io.write(sql.."\n") end
   end
end

return db_utils
