--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "prefs_utils"
local recording_utils = require "recording_utils"

local json = require "dkjson"

local ifid = _GET["ifid"]

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then
  return
end

if isEmptyString(ifid) then
  return
end

local if_name = getInterfaceName(ifid)

local result = {}

local status = "off"
local log = ""

if recording_utils.isActive(if_name) then
  status = "on"
end

local enabled = ntop.getCache('ntopng.prefs.'..if_name..'.traffic_recording.enabled')
if enabled ~= nil and enabled == "true" then
  if status ~= "on" then
    status = "failure"
    log = recording_utils.log(if_name, 10)
  end
end

result = {
  status = status,
  logs = log
}

print(json.encode(result))

