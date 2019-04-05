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
local ip = host_info["host"]
--print(ip)

local info = interface.getHostInfo(ip)
tprint(info)
--TODO: prendi i nomi?

--tskey string fe80::5e2e:4b27:7f84:97a7
--names.dhcp string fra-AspireV15
--ip string fe80::5e2e:4b27:7f84:97a7
--name string DESKTOP-4DGATJJ
--mac string 98:E7:F4:2F:5C:23
--names.resolved string pc-pellegrini.iit.cnr.it
--ipkey number 2452644127


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

--print( json.encode(matrix, {inednt=true}) )
print( json.encode( createMap4Target(matrix, "all", ip), {indent = true} ) ) 

