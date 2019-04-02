--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")
local matrix = interface.getArpStatsMatrixInfo()


sendHTTPContentTypeHeader('application/json')

local host_info = url2hostinfo(_GET)
local mac = host_info["host"]


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
    local src_mac, dst_mac
    local b,m = bindIpMac(matrix) --b contain [ip:mac] (source) values, and m is the Set of all the Macs.
    local v = 0

    for _, m_elem in ipairs(matrix) do
        for src_ip, s_elem in pairs(m_elem)do
            for dst_ip, stats in pairs(s_elem) do

                src_mac = stats["srcMac"] 
                dst_mac = stats["dstMac"]

                if (dst_mac == "FF:FF:FF:FF:FF:FF"  and b[dst_ip] ) then 
                    dst_mac = b[dst_ip]
                end

                if (dst_mac ~= "FF:FF:FF:FF:FF:FF") and (src_mac ~= dst_mac ) then

                    if      type == "requests" then v = stats["src2dst.requests"]
                    elseif  type == "replies" then v = stats["src2dst.replies"]
                    elseif  type == "all"     then v = stats["src2dst.requests"] + stats["src2dst.replies"]
                    end

                    if v > 0 then
                        if t[src_mac..dst_mac] then                            

                            t[src_mac..dst_mac].v = t[src_mac..dst_mac].v + v
                        else
                            t[src_mac..dst_mac] = { s = src_mac, d = dst_mac, v = v }
                        end
                    end
                    v = 0
                   
                    if      type == "requests" then v = stats["dst2src.requests"]
                    elseif  type == "replies" then v = stats["dst2src.replies"]
                    elseif  type == "all"     then v = stats["dst2src.requests"] + stats["dst2src.replies"]
                    end                    

                    if v > 0 then
                        if t[dst_mac..src_mac] then 
                            t[dst_mac..src_mac].v = t[dst_mac..src_mac].v + v
                        else
                            t[dst_mac..src_mac] = { s = dst_mac, d = src_mac, v = v }
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

    function cmp(a,b)
        return a.variable > b.variable
    end

    table.sort(t_res, cmp)

    return t_res
end

function macArpMap(mac_target, type)
    local map = createHeatmap(matrix, type)
    local res = {}

    for i,v in pairs(map) do
        if (v.variable == mac_target) then 
            table.insert(res, v)
        end
    end

    return res
end


--print( json.encode(matrix, {inednt=true}) )

--print( json.encode( createHeatmap(matrix, "requests"), {indent = true} ) )
print( json.encode( macArpMap(mac, "requests"), {indent = true} ) ) 

