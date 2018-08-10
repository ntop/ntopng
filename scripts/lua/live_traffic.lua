--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

local function send_error(error_type)
   local msg = "Generic error"
   if error_type == "not_found" then
      msg = "Host not found"
   elseif error_type == "not_granted" then
      msg = "Request not granted. Another request may be in progress. Retry later."
   end

   sendHTTPContentTypeHeader('application/json')
   print(json.encode({error = msg}))
end

local function send_status(status_type)
   sendHTTPContentTypeHeader('application/json')
   print(json.encode({status = status_type}))
end

interface.select(ifname)

local granted = true

if not granted then
   send_error("not_granted")
else
   local host       = _POST["host"]
   local duration   = tonumber(_POST["duration"])
   local bpf_filter = _POST["bpf_filter"]
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
