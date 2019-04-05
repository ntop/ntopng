--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

local matrix = interface.getArpStatsMatrixInfo()

local t_res = {}
local ip = nil

local host_info = url2hostinfo(_GET)
if host_info then
    ip = host_info["host"]
end

sendHTTPContentTypeHeader('application/json')

--split the string "s" with the "sep" separator
local function split(s,sep)
    local sep, fields = sep, {}
    local pattern = string.format("([^%s]+)", sep)
    s:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end


--return: t =  contain [ip:mac] (source) values
--        m = the Set of the Macs.
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


local function createHeatmap(matrix, type)
    local t = {}   
    local tmp = {}       
    local v = 0
    local t_res = {}
    local treshold = 1 --tmp

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
        
            function cmp(a,b)
                return a.y_label > b.y_label
            end
        
            table.sort(t_res, cmp)
        
        end
    end

    return t_res
end


local function createMap4Target(matrix, type, ip_target)
    local tmp = {}       
    local v = 0
    local t_res = {}
    local treshold = 1

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

    --tprint(t_res)
    return t_res
end


if ip then
    print( json.encode( createMap4Target(matrix, "requests", ip), {indent = true} ) )
else
    print( json.encode( createHeatmap(matrix, "all"), {indent = true} ) )
end

--print( json.encode( createChord(matrix), {indent = true} ) )

--print( json.encode(matrix, {inednt=true}) )


