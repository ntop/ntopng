--
-- (C) 2019 - ntop.org
--

--[[
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"
require "lua_utils"
local json = require("dkjson")

local matrix = interface.getArpStatsMatrixInfo()

local ts_custom = {}

--###############################################

local function bindIpMac(matrix)
   local t,m = {},{}
   local src_mac, dst_mac

   for _, m_elem in ipairs(matrix) do
       for src_ip, s_elem in pairs(m_elem)do
           for dst_ip, stats in pairs(s_elem) do

               src_mac = stats["srcMac"] 
               dst_mac = stats["dstMac"]
    
               if not t[src_ip] or (t[src_ip] ~= src_mac ) then 
                   t[src_ip] = src_mac
               end

               m[src_mac] = true
               if dst_mac ~= "FF:FF:FF:FF:FF:FF" then 
                   m[dst_mac] = true
               end
           end
       end
   end

   return t, m
end

--###############################################

local function test(matrix)
   local t = {}          
   local src_mac, dst_mac
   local b,m = bindIpMac(matrix) --b contain [ip:mac] (source) values, and m is the Set of the Macs.

   for _, m_elem in ipairs(matrix) do
       for src_ip, s_elem in pairs(m_elem)do
           for dst_ip, stats in pairs(s_elem) do

               src_mac = stats["srcMac"] 
               dst_mac = stats["dstMac"]

               if (dst_mac == "FF:FF:FF:FF:FF:FF"  and b[dst_ip] ) then 
                   dst_mac = b[dst_ip]
               end

               if (dst_mac ~= "FF:FF:FF:FF:FF:FF") and (src_mac ~= dst_mac ) then

                   if stats["src2dst.requests"] > 0 then
                       if t[src_mac..dst_mac] then 
                           t[src_mac..dst_mac].v = t[src_mac..dst_mac].v + stats["src2dst.requests"]
                       else
                           t[src_mac..dst_mac] = { s = src_mac, d = dst_mac, v = stats["src2dst.requests"] }
                       end
                   end

                   if stats["dst2src.requests"] > 0 then
                       if t[dst_mac..src_mac] then 
                           t[dst_mac..src_mac].v = t[dst_mac..src_mac].v + stats["dst2src.requests"]
                       else
                           t[dst_mac..src_mac] = { s = dst_mac, d = src_mac, v = stats["dst2src.requests"] }
                       end
                   end      
               end--end broadcast if
           end
       end
   end

   local t_res = {}
   for i,v in pairs(t) do
       table.insert( t_res, { group = v.s, variable = v.d, value = v.v })
   end

   return t_res
end

--###############################################


local function setup()
   local schema
   
   schema = ts_utils.newSchema("mac:arp_traffic", {step = 60, metrics_type=ts_utils.metrics.gauge})
   schema:addTag("ifid")
   --schema:addTag("mac")    --is this tag necessary?
   schema:addMetric("packets") 
end

function ts_custom.mac_update_stats(when, _ifname, ifstats, verbose) --TODO: is fun name correct?
   -- THIS IS THE FUNCTION THAT IS CALLED EVERY MINUTE BY NTOPNG
   -- USE THIS TO append() TO THE TIMESERIES

   --ma se qui metto la funzione che stampa il grafico? di sicuro si aggiona ma non credo sia il metodo giusto

   --LOGIC HERE


   ts_utils.append(("mac:arp_traffic",
		   {ifid = ifstats.id,
		    packets = ifstats.tcpPacketStats.retransmissions
		       + ifstats.tcpPacketStats.out_of_order
		       + ifstats.tcpPacketStats.lost},
		   when, verbose)
end

setup()
return ts_custom

]]
