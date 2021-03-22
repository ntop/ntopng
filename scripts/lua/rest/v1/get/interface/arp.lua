--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

local json = require("dkjson")

-- Parameters used for the rest answer --
local rc
local res = {}

--interface.select(ifname)
local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)

-- #####################################################################

local is_host
local stats
local table = {}

if isEmptyString(ifid) then
    rc = rest_utils.consts.err.invalid_interface
    rest_utils.answer(rc)
    return
 end

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

   for k,v in pairs(stats) do
      if k == "arp.requests" then
         res[#res + 1] = {}
         res[#res]["type"] = i18n("details.arp_requests")
         res[#res]["packets"] = v
      end
      if k == "arp.replies" then
         res[#res + 1] = {}
         res[#res]["type"] = i18n("details.arp_replies")
         res[#res]["packets"] = v
      end
   end

   rc = rest_utils.consts.success.ok
   rest_utils.answer(rc, res)
end
