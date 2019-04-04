--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")

local matrix = interface.getArpStatsMatrixInfo()

local t_res = {}


sendHTTPContentTypeHeader('application/json')
--sendHTTPContentTypeHeader('text/html')

--g: the type og graph ( 1 -sigma graph, 2 -heb graph )
--t: the type of data visualized (1-broadcast,2-replies,3-requests)
--local g,t = _GET["g"], _GET["t"]
--print(g..t)
--MISSING VALIDATION!


--========UTILS=======(but not currently used)==============================
--[[
--chack if inside "t" there is a mac named "name", if true return the index, nil otherwise 
local function containName(t,name)
    for i,v in pairs(t) do
        if v.labels == name then return i end
    end
    return nil
end

  ]]

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

--QUI HO TUTTI MAC (ANCHE CHI NON HA INVIATO REQ), SU ENTRAMBI GLI ASSI 
local function createHeatmapALLMACS(matrix)
    local t,tmp = {}, {}           --tmp:  [ index:"srcMAc-dstMac", value  ]
    local src_mac, dst_mac
    local b,m = bindIpMac(matrix) --b contain [ip:mac] (source) values, and m is the Set of the Macs.

    --print(json.encode( m, {indent = true}) )

    for i,_ in pairs(m) do
        for ii,_ in pairs(m) do
         tmp[i..ii] = {  group = i, variable = ii, value = 0 }
        end
    end

    for _, m_elem in ipairs(matrix) do
        for src_ip, s_elem in pairs(m_elem)do
            for dst_ip, stats in pairs(s_elem) do

                src_mac = stats["srcMac"] 
                dst_mac = stats["dstMac"]

                if (dst_mac ~= "FF:FF:FF:FF:FF:FF") or ( (dst_mac == "FF:FF:FF:FF:FF:FF") and b[dst_ip] ) then

                    if (dst_mac == "FF:FF:FF:FF:FF:FF") then 
                        dst_mac = b[dst_ip]
                    end

                    if stats["src2dst.requests"] > 0 then 
                        tmp[src_mac..dst_mac].value =  stats["src2dst.requests"]
                       
                    end

                    if stats["dst2src.requests"] > 0 then
                        tmp[dst_mac..src_mac].value =  stats["src2dst.requests"]
                       
                    end
                    
                end
            
            end
        end
    end

    for i,v in pairs(tmp) do
        table.insert( t, {  group = v.group, variable = v.variable, value = v.value })
    end


    return t

end

--TODO: prima di mettere dentro a "t"gli elementi, sarebbe meglio fare una tabella con chiave 
--      src_mac-dst_mac perché se il sorgente della request ha cambiato IP tale comunicazione 
--      sarà in un diverso elemento della matrice, e andrà a sostituire (o in conflitto) 
--      l'eventuale elemento precedente con i stessi mac src e dst.
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
        table.insert( t_res, { x_label = v.s, y_label = v.d, value = v.v })
    end

    function cmp(a,b)
        return a.y_label > b.y_label
    end

    table.sort(t_res, cmp)

    return t_res
end


--TODO: prima di mettere dentro a "t"gli elementi, sarebbe meglio fare una tabella con chiave 
--      src_mac-dst_mac perché se il sorgente della request ha cambiato IP tale comunicazione 
--      sarà in un diverso elemento della matrice, e andrà a sostituire (o in conflitto) 
--      l'eeventiale elemento precedente con i stessi mac src e dst.
--FATTO, TESTALO


local function createChord(matrix)
    local t = {}          
    local src_mac, dst_mac
    local b,m = bindIpMac(matrix)

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
        table.insert( t_res, { v.s, v.d, v.v })
    end

    return t_res
end

--print( json.encode( createHeatmap(matrix), {indent = true} ) )
--print( json.encode( createChord(matrix), {indent = true} ) )

--print( json.encode(matrix, {inednt=true}) )

print(matrix)

--print( json.encode( createHeatmap(matrix, "requests"), {indent = true} ) )
