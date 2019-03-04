--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
sendHTTPContentTypeHeader('text/html')
local json = require("dkjson")

interface.select(ifname)


local matrix = interface.getArpStatsMatrixInfo()
tprint(matrix)
for i,v in pairs(matrix) do 
    print("from: ".. v.me_src_mac.." --> to: ".. v.me_dst_mac .. "<p></p>")
    print("REQUEST (sent: " .. v["me_stats.sent.requests"] .. " received: ".. v["me_stats.rcvd.requests"]..") " )
    print("REPLIES (sent: " .. v["me_stats.sent.replies"] .. " received: ".. v["me_stats.rcvd.replies"] ..") ")
    print("<p></p><p></p>")

end

