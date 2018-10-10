--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "prefs_utils"
local recording_utils = require "recording_utils"

local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then
  return
end

local result = {}

local interfaces = recording_utils.getInterfaces()

for if_name,info in pairs(interfaces) do
  local if_id = if_name
  local status = "off"
  local log = ""

  if recording_utils.isActive(if_id) then
    status = "on"
  end

  local if_toggle = ntop.getCache("ntopng.prefs.traffic_recording.iface_on_"..if_id)
  if if_toggle ~= nil and if_toggle == "1" then
    if status ~= "on" then
      status = "failure"
      log = recording_utils.log(if_id, 10)
    end
  end

  result[if_id] = {
    status = status,
    logs = log
  }

end

print(json.encode(result))

