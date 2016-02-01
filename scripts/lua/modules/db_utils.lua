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
   follow = follow.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

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

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return nil
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
      return nil
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

   sql = "select COUNT(*) AS TOT_FLOWS, SUM(BYTES) AS TOT_BYTES, SUM(PACKETS) AS TOT_PACKETS FROM flowsv"..version.." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

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
      return nil
   else
      return(res)
   end
end


function getTopPeers(interface_id, version, host, protocol, port, l7proto, info, begin_epoch, end_epoch)
   if(host == nil or host == "") then return nil end
   if(version == nil) then version = 4 end

   if(info == "") then info = nil end
   if(l7proto == "") then l7proto = nil end
   if(protocol == "") then protocol = nil end

   sql = " SELECT "
   if(version == 4) then
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN INET_NTOA(IP_DST_ADDR) ELSE INET_NTOA(IP_SRC_ADDR) END PEER_ADDR, "
   else
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IP_DST_ADDR ELSE IP_SRC_ADDR END PEER_ADDR, "
   end

   sql = sql.."sum(BYTES) as TOT_BYTES, sum(PACKETS) as TOT_PACKETS, count(*) as TOT_FLOWS "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

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
   sql = sql.." group by least(IP_SRC_ADDR, IP_DST_ADDR), greatest(IP_SRC_ADDR, IP_DST_ADDR) "

   sql = sql.." order by TOT_BYTES desc limit 10"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return nil
   else
      return(res)
   end
end

function getTopL7Protocols(interface_id, version, host, protocol, port, info, begin_epoch, end_epoch)
   if(host == nil or host == "") then return nil end
   if(version == nil) then version = 4 end

   if(info == "") then info = nil end
   if(protocol == "") then protocol = nil end

   sql = " SELECT L7_PROTO, "
   sql = sql.."sum(BYTES) as TOT_BYTES, sum(PACKETS) as TOT_PACKETS, count(*) as TOT_FLOWS "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

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
      return nil
   else
      return(res)
   end
end


function getHostTopTalkers(interface_id, host, info, begin_epoch, end_epoch)
   if host == nil or host == "" then return nil end

   local version = 4
   if isIPv6(host) then version = 6 end
   if(info == "") then info = nil end

   sql = " SELECT "
   if(version == 4) then
      sql = sql.." CASE WHEN IP_SRC_ADDR = INET_ATON('"..host.."') THEN INET_NTOA(IP_DST_ADDR) ELSE INET_NTOA(IP_SRC_ADDR) END peer_addr, "
   else
      sql = sql.." CASE WHEN IP_SRC_ADDR = '"..host.."' THEN IP_DST_ADDR ELSE IP_SRC_ADDR END peer_addr, "
   end

   sql = sql.."sum(BYTES) as tot_bytes, sum(PACKETS) as tot_packets, count(*) as tot_flows "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

   if(info ~= nil) then sql = sql .." AND (INFO='"..info.."')" end

   if(version == 4) then
      sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..host.."') OR IP_DST_ADDR=INET_ATON('"..host.."'))"
   else
      sql = sql .." AND (IP_SRC_ADDR='"..host.."' OR IP_DST_ADDR='"..host.."')"
   end

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by least(IP_SRC_ADDR, IP_DST_ADDR), greatest(IP_SRC_ADDR, IP_DST_ADDR) "

   sql = sql.." order by TOT_BYTES desc limit 100"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return nil
   else
      return(res)
   end
end

function getHostTopApplications(interface_id, peer1, peer2, info, begin_epoch, end_epoch)
   -- peer1 cannot be nil, peer2 can
   -- if peer1 is nil nad peer2 is not nil, then top apps are for peer1
   -- if both peer2 and peer2 are not nil, then top apps are computed between peer1 and peer2
   if peer1 == nil or peer1 == "" then return nil end

   local version = 4
   if isIPv6(peer1) then version = 6 end
   if(info == "") then info = nil end

   sql = " SELECT L7_PROTO application, "
   sql = sql.."sum(BYTES) as tot_bytes, sum(PACKETS) as tot_packets, count(*) as tot_flows "
   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

   if(info ~= nil) then sql = sql .." AND (INFO='"..info.."')" end

   if(version == 4) then
      sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..peer1.."') OR IP_DST_ADDR=INET_ATON('"..peer1.."'))"
   else
      sql = sql .." AND (IP_SRC_ADDR='"..peer1.."' OR IP_DST_ADDR='"..peer1.."')"
   end

   if peer2 then
      if(version == 4) then
         sql = sql .." AND (IP_SRC_ADDR=INET_ATON('"..peer2.."') OR IP_DST_ADDR=INET_ATON('"..peer2.."'))"
      else
         sql = sql .." AND (IP_SRC_ADDR='"..peer2.."' OR IP_DST_ADDR='"..peer2.."')"
      end
   end

   -- we don't care about the order so we group by least and greatest
   sql = sql.." group by L7_PROTO "

   sql = sql.." order by TOT_BYTES desc limit 100"

   if(db_debug == true) then io.write(sql.."\n") end

   res = interface.execSQLQuery(sql)
   if(type(res) == "string") then
      if(db_debug == true) then io.write(res.."\n") end
      return nil
   else
      return(res)
   end
end


function getPeersTrafficHistogram(interface_id, peer1, peer2, info, begin_epoch, end_epoch)
   if peer1 == nil or peer1 == "" or peer2 == nil or peer2 == "" then return nil end

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
   sql = sql.." sum(BYTES) as tot_bytes, sum(PACKETS) as tot_packets, count(*) as tot_flows "

   sql = sql.." FROM flowsv"..version

   sql = sql.." WHERE FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   sql = sql.." AND (NTOPNG_INSTANCE_NAME='"..ntop.getPrefs()["instance_name"].."'OR NTOPNG_INSTANCE_NAME IS NULL)"
   sql = sql.." AND (INTERFACE='"..getInterfaceName(interface_id).."' OR INTERFACE IS NULL)"

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
      return nil
   else
      return(res)
   end
end
