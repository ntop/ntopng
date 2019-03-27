--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
ignore_post_payload_parse = 1
local json = require("dkjson")

local matrix = interface.getArpStatsMatrixInfo()

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

--split the string "s" with the "sep" separator
local function split(s,sep)
    local sep, fields = sep, {}
    local pattern = string.format("([^%s]+)", sep)
    s:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function tableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
--]]
  --=======================================================================

--[[ JSON SCHEMA for sigma.js graph

{
"nodes": [
    {
        "id": "chr1",
        "x": 0,
        "y": 0,
        "label": "Bob",
        "size": 8.75
    },
    {
        "id": "chr10",
        "label": "Alice",
        "x": 3,
        "y": 1,
        "size": 14.75
    }
],
"edges": [{
    "id": "1",
    "source": "chr1",
    "target": "chr10"
}]

]]--

--TODO: normalize pkt size (eg: size = (pkt_snt+rcv / tot_pkt_seen) * max_node_size ) ? )
--but maybe is not necessary, sigma.js already make an average

--the value of a t_nodes element is the size (not normalized) of the node (size = #request_pkt_sent )

--if "broadcast" is false all the broadcast requests will be ignored

--AT THE MOMENT THE CREATED GRAPH REPRESENT ONLY THE ARP REQUESTS (not replies)
local function createNodesAndEdges(matrix, broadcast)
    local t_nodes = {}
    local x,y = 10,10  
    local num, e_id = 0, 0
    local t = { nodes = {}, edges = {} }
    local source, target

    for _, m_elem in ipairs(matrix) do
        for src_mac, s_elem in pairs(m_elem)do
            for dst_mac, stats in pairs(s_elem) do

                --add dst_mac node and edges if broadcast is true or the pkt isn't broadcast
                if broadcast or (dst_mac ~= "FF:FF:FF:FF:FF:FF") then

                    if t_nodes[src_mac] then 
                        t_nodes[src_mac] = t_nodes[src_mac] + stats["src2dst.requests"]
                    else
                        t_nodes[src_mac] = stats["src2dst.requests"] 
                    end 

                    if t_nodes[dst_mac] then 
                        t_nodes[dst_mac] = t_nodes[dst_mac] + stats["dst2src.requests"]
                    else
                        t_nodes[dst_mac] = stats["dst2src.requests"]
                    end      

                    if stats["src2dst.requests"] > 0 then 
                        table.insert( t.edges, 
                            {   id = e_id,
                                source = src_mac,
                                target = dst_mac,
                                size = stats["src2dst.requests"],
                                label =  stats["src2dst.requests"].." req snt"
                            }
                        ) 
                    end         
                    e_id = e_id + 1

                    if stats["dst2src.requests"] > 0 then 
                    table.insert( t.edges, 
                            {   id = e_id,
                                source = dst_mac,
                                target = src_mac,
                                size = stats["dst2src.requests"],
                                label =  stats["dst2src.requests"].." req snt"
                            }
                        ) 
                    end         
                    e_id = e_id + 1

                end--end if
            end
        end
    end
    
    for i,v in pairs(t_nodes) do
        x = math.floor(math.random(0,500))
        y = math.floor(math.random(0,350))
        table.insert( t.nodes, { id = i, label = i, x = x , y = y, size = v  }) 
    end

    return t
end

----WIP--------WIP--------WIP--------WIP--------WIP--------WIP--------WIP--------WIP--------
--------------------------------------------------------------------------------------------
----------------------------Hierarchical Edge Bundling--------------------------------------
--------------------------------------------------------------------------------------------

--PROBLEMA: le "foglie", cioè l'ultima parola dopo il punto. devono essere uniche
    -- ma se A invia una req a B e poi B invia una req ad A, ciò viene meno
--IDEA: creo una finta gerarchia in base alle comunicazioni:
    --se A invia a B, allora il nome di B diventa "A.B". e così per ogni comunicazione

--TODO: unire i 3 cici dove possibile
local function createHierarchyAndImport(matrix,broadcast)
    local t_names = {}
    local tbl = {}
    local pkt_num = 0

    --creo i nodi del grafo
    for _, m_elem in ipairs(matrix) do
        for src_mac, s_elem in pairs(m_elem)do
            for dst_mac, stats in pairs(s_elem) do

                --i due punti separatori dei byte del mac danno noia allo script js, metto il trattino
                src_mac = string.gsub(src_mac, ":", "-")
                dst_mac = string.gsub(dst_mac, ":", "-")

                t_names[src_mac] = {name = src_mac, imports = {} }

                if dst_mac ~= "FF-FF-FF-FF-FF-FF" then
                    t_names[dst_mac] = {name = dst_mac, imports = {} }
                end
            end
        end
    end

    --ho la mappa dei mac dentro t_names, ora compongo la gerarchia fittizia
    for _, m_elem in ipairs(matrix) do
        for src_mac, s_elem in pairs(m_elem)do
            for dst_mac, stats in pairs(s_elem) do

                src_mac = string.gsub(src_mac, ":", "-")
                dst_mac = string.gsub(dst_mac, ":", "-")

                pkt_num = stats["src2dst.requests"]
                if pkt_num > 0 then 

                    if dst_mac ~= "FF-FF-FF-FF-FF-FF" then
                        t_names[dst_mac].name = src_mac.."."..t_names[dst_mac].name 
                    end
                end
            
                pkt_num =  stats["dst2src.requests"]
                if pkt_num > 0 then
                    t_names[src_mac].name = dst_mac.."."..t_names[src_mac].name 
                end

            end
        end
    end

    --ho i nomi "lunghi", aggiungo gli import 
    for _, m_elem in ipairs(matrix) do
        for src_mac, s_elem in pairs(m_elem)do
            for dst_mac, stats in pairs(s_elem) do

                src_mac = string.gsub(src_mac, ":", "-")
                dst_mac = string.gsub(dst_mac, ":", "-")


                pkt_num = stats["src2dst.requests"]
                if pkt_num > 0 then 
                    if dst_mac ~= "FF-FF-FF-FF-FF-FF" and (t_names[dst_mac].name ~= t_names[src_mac].name) then

                        table.insert( t_names[src_mac].imports, t_names[dst_mac].name )  
                    end               
                end
            
                pkt_num =  stats["dst2src.requests"]
                if pkt_num > 0 then

                    if t_names[dst_mac].name ~= t_names[src_mac].name then 
                        table.insert( t_names[dst_mac].imports, t_names[src_mac].name )   
                    end
                end


            end
        end
    end

    --genero la tabella pronta per divenire il file json
    for i,v in pairs(t_names) do
        --tprint(v)
        --"size" non viene preso in considerazione per lo spessore dell'arco
        table.insert(tbl, { name = v.name, size = math.floor(math.random(100,10000)), imports = v.imports } )
    end

    return tbl

end

--print( json.encode( createNodesAndEdges(matrix, false), {indent = true} ) )

print( json.encode( createHierarchyAndImport(matrix, false), {indent = true} ) )

--print( json.encode( matrix,  {indent = true} ) )
