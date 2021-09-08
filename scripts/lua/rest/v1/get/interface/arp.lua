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

-- #####################################################################

local stats

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

-- Show ARP stats for interface
local stats = interface.getStats()

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
