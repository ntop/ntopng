--
-- (C) 2014-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"

local db_debug = true

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

function getInterfaceTopFlows(interface_id, version, host, l7proto, l4proto, port, info, begin_epoch, end_epoch, offset, max_num_flows, sort_column, sort_order)
   -- CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON

   if(version == 4) then 
      sql = "select INET_NTOA(IP_SRC_ADDR) AS IP_SRC_ADDR,INET_NTOA(IP_DST_ADDR) AS IP_DST_ADDR"
   else
      sql = "select IP_SRC_ADDR, IP_DST_ADDR"
   end

   follow = " ,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,BYTES,idx,L7_PROTO,INFO from flowsv"..version.."_"..interface_id.." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   
   if((l7proto ~= "") and (l7proto ~= "-1")) then follow = follow .." AND L7_PROTO="..l7proto end
   if((l4proto ~= "") and (l4proto ~= "-1")) then follow = follow .." AND PROTOCOL="..l4proto end
   if(port ~= "") then follow = follow .." AND (L4_SRC_PORT="..port.." OR L4_DST_PORT="..port..")" end
   if(info ~= "") then follow = follow .." AND (INFO='"..info.."')" end

   if((host ~= nil) and (host ~= "")) then 
      if(version == 4) then
	 rsp = expandIpV4Network(host)
	 follow = follow .." AND (((IP_SRC_ADDR>="..rsp[1]..") AND (IP_SRC_ADDR <= "..rsp[2].."))"
	 follow = follow .." OR ((IP_DST_ADDR>="..rsp[1]..") AND (IP_DST_ADDR <= "..rsp[2]..")))"
      else
	 follow = follow .." AND (IP_SRC_ADDR='"..host.."' OR IP_DST_ADDR='"..host.."')"
      end
   end

   follow = follow .." order by "..sort_column.." "..sort_order.." limit "..max_num_flows.." OFFSET "..offset 

   sql = sql .. follow

   -- io.write(sql.."\n")

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

   follow = " ,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,BYTES,idx,L7_PROTO,INFO,CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON from flowsv"..version.."_"..interface_id.." where idx="..flow_idx
   
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

   sql = "select COUNT(*) AS TOT_FLOWS, SUM(BYTES) AS TOT_BYTES, SUM(PACKETS) AS TOT_PACKETS FROM flowsv"..version.."_"..interface_id.." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch
   if((l7proto ~= nil) and (l7proto ~= "")) then sql = sql .." AND L7_PROTO="..l7proto end
   if((protocol ~= nil) and (protocol ~= "")) then sql = sql .." AND PROTOCOL="..protocol end
   if(info ~= "") then sql = sql .." AND (INFO='"..info.."')" end

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
