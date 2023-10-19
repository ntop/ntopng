--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local matrix = interface.getArpStatsMatrixInfo()
local arpMatrixModule = {}

function arpMatrixModule.arpCheck(host_ip)
    if not (matrix and host_ip) then return false end
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
                    
                return true
                end
            end
        end

    end
    return false
 end


return arpMatrixModule






