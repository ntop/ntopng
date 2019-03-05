--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('application/json')
local json = require("dkjson")

interface.select(ifname)



--matrix = interface.getArpStatsMatrixInfo()

--FOR NOW THIS IS ONLY FOR TESTING

--tprint(matrix)


--[[   here, the name of the stats are wrong
for i,v in pairs(matrix) do 
    print("from: ".. src_mac.." --> to: ".. dst_mac .. "<p></p>")
    print("REQUEST (sent: " .. v["me_stats.sent.requests"] .. " received: ".. v["me_stats.rcvd.requests"]..") " )
    print("REPLIES (sent: " .. v["me_stats.sent.replies"] .. " received: ".. v["me_stats.rcvd.replies"] ..") ")
    print("<p>-------------</p>")
end
--]]


local function containName(t,name)
    for i,v in pairs(t) do
        if v.name == name then return i end
    end
    return nil
end

function split(s,sep)
    local sep, fields = sep, {}
    local pattern = string.format("([^%s]+)", sep)
    s:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
 end


--the created json file will contain only the relations between MACs, regardless the type of the pkts seen
local function createRelations()  
    matrix = interface.getArpStatsMatrixInfo()
    local tbl = {}

    for i,v in pairs(matrix) do 
        local imports = {}
        local index = 0
        local macs = split(i,".")
        local src_mac, dst_mac = macs[1], macs[2]

        index = containName(tbl, src_mac)

        if index ~= nil then -- the elem exist add import/counter!?
            table.insert( tbl[index].imports, dst_mac )

        else --add element 
            --tbl[src_mac] = { name = src_mac, imports = {dst_mac} }
            table.insert(tbl, { name = src_mac, imports = {dst_mac} })
        end
        --------------------------------------------------------------------------------------------
        index = containName(tbl, dst_mac)
        if index ~= nil then 

            table.insert( tbl[index].imports, src_mac )
               
        else 
            --tbl[dst_mac] = { name = dst_mac, imports = {src_mac} }
            table.insert(tbl, { name = dst_mac, imports = {src_mac}  })
        end
    end

    return json.encode(tbl, { indent = true })
end


--local a,b,c = json.decode( createRelations(),1,nil )
print(createRelations())