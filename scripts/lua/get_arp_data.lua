--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

--interface.select(ifname)
local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)

-- #####################################################################

interface.select(ifid)

local breakdown = {}

if not isEmptyString(ifid) and not isEmptyString(host_info["host"]) then
   local stats = interface.getMacInfo(host_info["host"])

   if stats then
      -- Show ARP sent/recv breakdown
      local arp_sent = stats["arp_requests.sent"] + stats["arp_replies.sent"]
      local arp_rcvd = stats["arp_requests.rcvd"] + stats["arp_replies.rcvd"]

      breakdown[#breakdown + 1] = {label=i18n("sent"), value=arp_sent}
      breakdown[#breakdown + 1] = {label=i18n("received"), value=arp_rcvd}
   end
end

sendHTTPContentTypeHeader('text/html')
print(json.encode(breakdown, nil))
