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
   local host = _GET["host"]
   local action = _GET["action"]

   if(action ~= nil and action == 'stop') then

     interface.stopLiveCapture(host)

     send_status("stopped")

   elseif(action ~= nil and action == 'status') then
     local status = 'stopped'

     local rc = interface.dumpLiveCaptures()
     for _,v in ipairs(rc) do
       if(v.host ~= nil and v.host == host) then
         status = 'running'
       end
     end

     send_status(status)

   else -- start
     local fname = ifname

     if(host ~= nil) then
        fname = fname .. "_"..host
     end

     fname = fname .."_live.pcap"
   
     sendHTTPContentTypeHeader('application/vnd.tcpdump.pcap', 'attachment; filename="'..fname..'"')
   
     interface.liveCapture(host)
   end
end
