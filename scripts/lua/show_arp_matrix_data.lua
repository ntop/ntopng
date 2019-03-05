--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
sendHTTPContentTypeHeader('text/html')
local json = require("dkjson")

interface.select(ifname)



local function containName(t,name)
    for i,v in pairs(t) do

        if v.name == name then return i end

    end

    return nil
end

matrix = interface.getArpStatsMatrixInfo()


--tprint(matrix)
--[[
for i,v in pairs(matrix) do 
    print("from: ".. v.me_src_mac.." --> to: ".. v.me_dst_mac .. "<p></p>")
    print("REQUEST (sent: " .. v["me_stats.sent.requests"] .. " received: ".. v["me_stats.rcvd.requests"]..") " )
    print("REPLIES (sent: " .. v["me_stats.sent.replies"] .. " received: ".. v["me_stats.rcvd.replies"] ..") ")
    print("<p>-------------</p>")
end
--]]


--TODO: crea file json con i mac src e dst (gli import sono i collegamenti)
--this json file will contain only the relations between MACs, regardless the type of the pkts seen
local function createRelations()  
    matrix = interface.getArpStatsMatrixInfo()
    local tbl = {}

    for i,v in pairs(matrix) do 
        local imports = {}
        local index = 0

        index = containName(tbl, v.me_src_mac)
        if index ~= nil then -- the elem exist add import/counter!?
            
            table.insert( tbl[index].imports, v.me_dst_mac )
               
        else --add element 
            
            --tbl[v.me_src_mac] = { name = v.me_src_mac, imports = {v.me_dst_mac} }
            table.insert(tbl, { name = v.me_src_mac, imports = {v.me_dst_mac} })

        end

        --------------------------------------------------------------------------------------------
        index = containName(tbl, v.me_dst_mac)
        if index ~= nil then 

            table.insert( tbl[index].imports, v.me_src_mac )
               
        else 

            --tbl[v.me_dst_mac] = { name = v.me_dst_mac, imports = {v.me_src_mac} }
            table.insert(tbl, { name = v.me_dst_mac, imports = {v.me_src_mac}  })
            
        end

    end
    tprint(tbl)

    return json.encode(tbl, { indent = true })
end

--||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\


local function createRelations2()  
    matrix = interface.getArpStatsMatrixInfo()
    local tbl = {}

    for i,v in pairs(matrix) do 
        local imports = {}
        local index = 0

        index = containName(tbl, v.me_src_mac)
        if index ~= nil then -- the elem exist add import/counter!?
            
            table.insert( tbl[index].imports, v.me_dst_mac )
               
        else --add element 
            
            --tbl[v.me_src_mac] = { name = v.me_src_mac, imports = {v.me_dst_mac} }
            table.insert(tbl, { name = v.me_src_mac, imports = {v.me_dst_mac} })

        end

        --------------------------------------------------------------------------------------------
        index = containName(tbl, v.me_dst_mac)
        if index ~= nil then 

            table.insert( tbl[index].imports, v.me_src_mac )
               
        else 

            --tbl[v.me_dst_mac] = { name = v.me_dst_mac, imports = {v.me_src_mac} }
            table.insert(tbl, { name = v.me_dst_mac, imports = {v.me_src_mac}  })
            
        end

    end
    tprint(tbl)

    return json.encode(tbl, { indent = true })
end


--local a,b,c = json.decode( createRelations(),1,nil )
print(createRelations())