--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local recording_utils = require "recording_utils"

--
-- Download data produced by an extraction by job ID
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/pcap/extraction/data.lua?job_id=1&file_id=1
--

local ifid = _GET["ifid"]
local job_id = _GET["job_id"]
local file_id = _GET["file_id"] or "1"

if not isEmptyString(ifid) then
   interface.select(ifid)
end

local function send_error(error_type)
   local msg = ""
   if error_type == "not_found" then
      msg = i18n("traffic_recording.not_found")
   elseif error_type == "not_granted" then
      msg = i18n("traffic_recording.error_not_granted")
   end

   sendHTTPContentTypeHeader('application/json')
   print(json.encode({error = msg}))
end

if not recording_utils.isAvailable() then
  send_error("not_granted")
elseif isEmptyString(job_id) then
  send_error("not_found")
else

  job_id = tonumber(job_id)
  file_id = tonumber(file_id)

  local job_files = recording_utils.getJobFiles(job_id)

  if job_files[file_id] == nil then
    send_error("not_found")
  else
    local file = job_files[file_id]
    sendHTTPContentTypeHeader('application/vnd.tcpdump.pcap', 'attachment; filename="extraction_'..job_id..'_'..file_id..'.pcap"')
    ntop.dumpBinaryFile(file)
  end
end
