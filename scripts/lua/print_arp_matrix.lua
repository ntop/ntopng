--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
sendHTTPContentTypeHeader('text/html')
local json = require("dkjson")

interface.select(ifname)

matrix = interface.getArpStatsMatrixInfo()

for i,v in pairs(matrix) do 
    print(  "<p>FROM: " .. (v["me_src_mac"]).. " --> TO " .. (v["me_dst_mac"]).."</p>" )   
    print( "<p>replies sent: "..(v["me_stats.sent.replies"])..
        " replies received: "..(v["me_stats.rcvd.replies"])..
        " requests sent: "..(v["me_stats.sent.requests"])..
        " requests receive: "..(v["me_stats.rcvd.requests"]).."</p>"
    )
end



