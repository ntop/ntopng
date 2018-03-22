--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
sendHTTPContentTypeHeader('text/html')
local json = require("dkjson")

interface.select(ifname)
host_info = url2hostinfo(_GET)

-- #####################################################################

local is_host

if(host_info["host"] ~= nil) then
   local breakdown = {}

   -- Show ARP sent/recv breakdown 
   stats = interface.getMacInfo(host_info["host"])

   if stats ~= nil then
      local arp_sent = stats["arp_requests.sent"] + stats["arp_replies.sent"]
      local arp_rcvd = stats["arp_requests.rcvd"] + stats["arp_replies.rcvd"]

      breakdown[#breakdown + 1] = {label=i18n("sent"), value=arp_sent}
      breakdown[#breakdown + 1] = {label=i18n("received"), value=arp_rcvd}
   end

   print(json.encode(breakdown, nil))
else
   -- Show ARP stats for interface
   stats = interface.getStats()

   print('<tr><td>'..i18n("graphs.arp_requests").."</td><td align='right'>"..(stats["arp.requests"]).."</td></tr>")
   print('<tr><td>'..i18n("graphs.arp_replies").."</td><td align='right'>"..(stats["arp.replies"]).."</td></tr>")
end
