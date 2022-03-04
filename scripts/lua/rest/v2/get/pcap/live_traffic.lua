--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

--
-- Run a live traffic capture
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "duration": 10, "bpf_filter": "" }' http://localhost:3000/lua/rest/v2/get/pcap/live_traffic.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local function send_error(error_type)
   local msg = i18n("live_traffic.error_generic")
   if error_type == "not_found" then
      msg = i18n("live_traffic.error_not_found")
   elseif error_type == "not_granted" then
      msg = i18n("live_traffic.error_not_granted")
   end

   sendHTTPContentTypeHeader('application/json')
   print(json.encode({error = msg}))
end

local function send_status(status_type)
   sendHTTPContentTypeHeader('application/json')
   print(json.encode({status = status_type}))
end

interface.select(ifname)

if not ntop.isPcapDownloadAllowed() then
   send_error("not_granted")
else
   local host       = _GET["host"]
   local duration   = tonumber(_GET["duration"])
   local bpf_filter = _GET["bpf_filter"]
   local fname      = ifname

   if(host ~= nil) then
      fname = fname .. "_"..host
   end

   if((bpf_filter ~= nil) and (bpf_filter ~= "")) then
      fname = fname .. "_filtered"
   end

   fname = fname .."_live.pcap"

   if((duration == nil) or (duration < 0) or (duration > 600)) then
      duration = 60
   end

   sendHTTPContentTypeHeader('application/vnd.tcpdump.pcap', 'attachment; filename="'..fname..'"')

   interface.liveCapture(host, duration, bpf_filter)
end
