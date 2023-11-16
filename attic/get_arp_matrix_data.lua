--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")
sendHTTPContentTypeHeader('application/json')

local matrix = interface.getArpStatsMatrixInfo()

local host_info   = url2hostinfo(_GET)
local host_ip     = host_info["host"]
local page = _GET["page"]

local treshold = 0

local function createHeatmap(matrix, type)

    if not matrix then return nil end

    local t = {}   
    local tmp = {}       
    local v = 0
    local t_res = {}
    
    -- function cmp(a,b)
    --     return a.y_label > b.y_label
    -- end

    for _, m_elem in pairs(matrix) do
        for i,stats in pairs(m_elem)do
            tmp = split(i,"-")
            src_ip = tmp[1]
            dst_ip = tmp[2]

            if      type == "requests" then v = stats["src2dst.requests"]
            elseif  type == "replies"  then v = stats["src2dst.replies"]
            elseif  type == "all"      then v = stats["src2dst.requests"] + stats["src2dst.replies"]
            end

            if v > treshold  then
                table.insert( t_res, { x_label = dst_ip, y_label = src_ip, value = v })
            end
            v = 0
           
            if      type == "requests" then v = stats["dst2src.requests"]
            elseif  type == "replies"  then v = stats["dst2src.replies"]
            elseif  type == "all"      then v = stats["dst2src.requests"] + stats["dst2src.replies"]
            end                    

            if v > treshold then
                table.insert( t_res, { x_label = src_ip, y_label = dst_ip, value = v })
            end      
            --table.sort(t_res, cmp) --for lexicographical order
        end
    end

    return t_res
end

--NOTE: function currently not used
local function createMap4Target(matrix, type, ip_target)
    local tmp = {}       
    local v = 0
    local t_res = {}
    local treshold = 0

    for _, m_elem in pairs(matrix) do
        for i,stats in pairs(m_elem)do

            tmp = split(i,"-")
            src_ip = tmp[1]
            dst_ip = tmp[2]

            if      type == "requests" then v = stats["src2dst.requests"]
            elseif  type == "replies"  then v = stats["src2dst.replies"]
            elseif  type == "all"      then v = stats["src2dst.requests"] + stats["src2dst.replies"]
            end

            if (v > treshold) and (src_ip == ip_target)  then
                table.insert( t_res, { x_label = dst_ip, y_label = src_ip, value = v })
            end
            v = 0
           
            if      type == "requests" then v = stats["dst2src.requests"]
            elseif  type == "replies"  then v = stats["dst2src.replies"]
            elseif  type == "all"      then v = stats["dst2src.requests"] + stats["dst2src.replies"]
            end                    

            if (v > treshold) and (dst_ip == ip_target)   then
                table.insert( t_res, { x_label = src_ip, y_label = dst_ip, value = v })
            end          

        end
    end

    return t_res
end

--return 2 counters: number of ARP requests received, and the number of senders for that requests 
local function arpTalkers(matrix, host_ip)
    local req_num = 0;
    local talkers_num = 0;

    if (matrix and host_ip)  then 

       for _, m_elem in pairs(matrix) do
          for i, stats in pairs(m_elem)do
             tmp = split(i,"-")
             src_ip = tmp[1]
             dst_ip = tmp[2]

             if  ((stats["src2dst.requests"] > 0) and (src_ip == host_ip)) or
                   ((stats["dst2src.requests"] > 0) and (dst_ip == host_ip))then
                   
                req_num = req_num + stats["src2dst.requests"] + stats["dst2src.requests"]
                talkers_num = talkers_num + 1
             end
          end
       end

    end
    return {talkers_num = talkers_num, req_num = req_num}
 end

if host_ip then
    print( json.encode( arpTalkers(matrix, host_ip) ) )
else 
    print( json.encode( createHeatmap(matrix, "all"), {indent = true} ) )
end






