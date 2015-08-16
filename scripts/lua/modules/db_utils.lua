--
-- (C) 2014-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "template"


local db_debug = false

--- ====================================================================

function getInterfaceTopFlows(interface_id, version, begin_epoch, end_epoch, offset, max_num_flows, sort_column, sort_order)
   -- CONVERT(UNCOMPRESS(JSON) USING 'utf8') AS JSON
   sql = "select INET_NTOA(IPV4_SRC_ADDR) AS IPV4_SRC_ADDR,INET_NTOA(IPV4_DST_ADDR) AS IPV4_DST_ADDR,L4_SRC_PORT,L4_DST_PORT,VLAN_ID,PROTOCOL,FIRST_SWITCHED,LAST_SWITCHED,PACKETS,BYTES,idx,L7_PROTO from flowsv"..version.."_"..interface_id.." where FIRST_SWITCHED <= "..end_epoch.." and FIRST_SWITCHED >= "..begin_epoch.." order by "..sort_column.." "..sort_order.." limit "..max_num_flows.." OFFSET "..offset 

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

function getInterfaceFlows(interface_id, version, host, vlan, begin_epoch, end_epoch, limit_low, limit_high)
end

--- ====================================================================

function getHostTopFlows(interface_id, version, host, vlan, begin_epoch, end_epoch, max_num_flows)
end

--- ====================================================================

function getHostFlows(interface_id, version, host, vlan, begin_epoch, end_epoch, limit_low, limit_high)
end

